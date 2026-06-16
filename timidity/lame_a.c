/*
    TiMidity++ -- MIDI to WAVE converter and player
    Copyright (C) 1999-2004 Masanao Izumo <mo@goice.co.jp>
    Copyright (C) 1995 Tuukka Toivonen <tt@cgs.fi>

    lame_a.c

    Functions to output MP3 via LAME.
*/

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif /* HAVE_CONFIG_H */
#include <stdio.h>
#include <stdlib.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifndef NO_STRING_H
#include <string.h>
#else
#include <strings.h>
#endif
#include <fcntl.h>

#include <lame/lame.h>

#include "lame_a.h"
#include "interface.h"
#include "timidity.h"
#include "common.h"
#include "output.h"
#include "controls.h"
#include "instrum.h"
#include "playmidi.h"
#include "readmidi.h"

#ifdef __W32__
#include <io.h>
#endif

#if defined(IA_W32GUI) || defined(IA_W32G_SYN)
extern char *w32g_output_dir;
extern int w32g_auto_output_mode;
#endif

static int open_output(void);
static void close_output(void);
static int output_data(char *buf, int32 nbytes);
static int acntl(int request, void *arg);

#define dpm lame_play_mode

PlayMode dpm = {
    DEFAULT_RATE,
    PE_16BIT|PE_SIGNED,
    PF_PCM_STREAM|PF_FILE_OUTPUT,
    -1,
    {0,0,0,0,0},
    "MP3 LAME", 'L',
    NULL,
    open_output,
    close_output,
    output_data,
    acntl
};

static lame_global_flags *gf = NULL;
static unsigned char mp3buf[LAME_MAXMP3BUFFER];

volatile lame_ConfigDialogInfo_t lame_ConfigDialogInfo;

int lame_ConfigDialogInfoInit(void)
{
    if(lame_ConfigDialogInfo_initialized)
        return 0;
    lame_ConfigDialogInfo.optIDC_CHECK_DEFAULT = 1;
    lame_ConfigDialogInfo.optIDC_CHECK_VBR = 0;
    lame_ConfigDialogInfo.optIDC_COMBO_VBR_QUALITY = 4;
    lame_ConfigDialogInfo.optIDC_COMBO_CBR_BITRATE = 8; /* 128kbps index 8 */
    lame_ConfigDialogInfo.optIDC_CHECK_ENCODE_MODE = 1;
    lame_ConfigDialogInfo.optIDC_COMBO_ENCODE_MODE = 1;
    lame_ConfigDialogInfo.optIDC_CHECK_ALGO_QUALITY = 1;
    lame_ConfigDialogInfo.optIDC_COMBO_ALGO_QUALITY = 2;
    lame_ConfigDialogInfo.optIDC_CHECK_LOWPASS = 0;
    strcpy((char *)lame_ConfigDialogInfo.optIDC_EDIT_LOWPASS, "0");
    lame_ConfigDialogInfo.optIDC_CHECK_COMMANDLINE_OPTS = 0;
    lame_ConfigDialogInfo.optIDC_EDIT_COMMANDLINE_OPTION[0] = '\0';
    lame_ConfigDialogInfo.optOutputFormat = 0;
    lame_ConfigDialogInfo.optOutputDir[0] = '\0';
    lame_ConfigDialogInfo_initialized = 1;
    return 0;
}

int lame_ConfigDialogInfo_initialized = 0;

int lame_ConfigDialogInfoApply(void)
{
    if(!lame_ConfigDialogInfo_initialized) {
        lame_ConfigDialogInfoInit();
        lame_ConfigDialogInfo_initialized = 1;
    }
    return 0;
}

static int lame_ConfigDialogInfoSaveINI_pref(const char *section)
{
    if(section == NULL) section = "LAME";
    /* Implemented in w32g_ini.c */
    return 0;
}

static int lame_ConfigDialogInfoLoadINI_pref(const char *section)
{
    if(section == NULL) section = "LAME";
    /* Implemented in w32g_ini.c */
    return 0;
}

static int lame_output_open(const char *fname)
{
    int fd, nch;

    if(fname == NULL || fname[0] == '\0')
        return -1;

    if(strcmp(fname, "-") == 0)
        fd = 1;
    else
    {
        fd = open(fname, FILE_OUTPUT_MODE);
        if(fd < 0)
        {
            ctl->cmsg(CMSG_ERROR, VERB_NORMAL,
                "%s: %s", fname, strerror(errno));
            return -1;
        }
    }

    nch = (dpm.encoding & PE_MONO) ? 1 : 2;

    if(gf != NULL)
    {
        lame_close(gf);
        gf = NULL;
    }

    gf = lame_init();
    if(gf == NULL)
    {
        ctl->cmsg(CMSG_ERROR, VERB_NORMAL,
            "lame_a: lame_init failed");
        if(fd != 1) close(fd);
        return -1;
    }

    lame_set_errorf(gf, NULL);
    lame_set_debugf(gf, NULL);
    lame_set_msgf(gf, NULL);

    lame_set_in_samplerate(gf, dpm.rate);
    lame_set_num_channels(gf, nch);
    lame_set_out_samplerate(gf, dpm.rate);

    /* apply config dialog settings */
    if(!lame_ConfigDialogInfo_initialized) {
        lame_ConfigDialogInfoInit();
        lame_ConfigDialogInfo_initialized = 1;
    }
    if(lame_ConfigDialogInfo.optIDC_CHECK_DEFAULT) {
        /* use hardcoded defaults (VBR q=5, joint stereo, algo=2) */
        lame_set_VBR(gf, vbr_default);
        lame_set_VBR_q(gf, 5);
        lame_set_mode(gf, JOINT_STEREO);
        lame_set_quality(gf, 2);
    } else {
        /* apply user-configured settings */
        if(lame_ConfigDialogInfo.optIDC_CHECK_VBR) {
            int q = lame_ConfigDialogInfo.optIDC_COMBO_VBR_QUALITY;
            if(q < 0) q = 0; if(q > 9) q = 9;
            lame_set_VBR(gf, vbr_default);
            lame_set_VBR_q(gf, q);
        } else {
            int cbr_table[] = {32,40,48,56,64,80,96,112,128,160,192,256,320};
            int idx = lame_ConfigDialogInfo.optIDC_COMBO_CBR_BITRATE;
            if(idx < 0) idx = 5; if(idx > 12) idx = 5;
            lame_set_brate(gf, cbr_table[idx]);
        }
        if(lame_ConfigDialogInfo.optIDC_CHECK_ENCODE_MODE) {
            switch(lame_ConfigDialogInfo.optIDC_COMBO_ENCODE_MODE) {
            case 0: lame_set_mode(gf, STEREO); break;
            case 2: lame_set_mode(gf, JOINT_STEREO); break; /* forced */
            case 3: lame_set_mode(gf, DUAL_CHANNEL); break;
            case 4: lame_set_mode(gf, MONO); break;
            case 5: lame_set_mode(gf, MONO); break; /* Left Only -> mono */
            case 6: /* Auto */ break;
            default: lame_set_mode(gf, JOINT_STEREO); break;
            }
        }
        if(lame_ConfigDialogInfo.optIDC_CHECK_ALGO_QUALITY) {
            int q = lame_ConfigDialogInfo.optIDC_COMBO_ALGO_QUALITY;
            if(q < 0) q = 0; if(q > 9) q = 9;
            lame_set_quality(gf, q);
        }
        if(lame_ConfigDialogInfo.optIDC_CHECK_LOWPASS) {
            int lp = atoi((char *)lame_ConfigDialogInfo.optIDC_EDIT_LOWPASS);
            if(lp > 0 && lp <= 20000)
                lame_set_lowpassfreq(gf, lp);
        }
    }

    /* command-line options override everything */
    if(lame_ConfigDialogInfo.optIDC_CHECK_COMMANDLINE_OPTS
        && lame_ConfigDialogInfo.optIDC_EDIT_COMMANDLINE_OPTION[0] != '\0')
    {
        /* tokenize and apply (supports LAME-style args) */
        char *p, *buf;
        buf = (char *)safe_malloc(strlen((char *)lame_ConfigDialogInfo.optIDC_EDIT_COMMANDLINE_OPTION) + 1);
        strcpy(buf, (char *)lame_ConfigDialogInfo.optIDC_EDIT_COMMANDLINE_OPTION);
        p = strtok(buf, " \t");
        while(p) {
            if(strcmp(p, "-b") == 0) {
                p = strtok(NULL, " \t"); if(!p) break;
                lame_set_VBR(gf, vbr_off);
                lame_set_brate(gf, atoi(p));
            } else if(strcmp(p, "-V") == 0) {
                p = strtok(NULL, " \t"); if(!p) break;
                lame_set_VBR(gf, vbr_default);
                lame_set_VBR_q(gf, atoi(p));
            } else if(strcmp(p, "-q") == 0) {
                p = strtok(NULL, " \t"); if(!p) break;
                lame_set_quality(gf, atoi(p));
            } else if(strcmp(p, "-m") == 0) {
                p = strtok(NULL, " \t"); if(!p) break;
                switch(p[0]) {
                case 's': lame_set_mode(gf, STEREO); break;
                case 'j': case 'a': lame_set_mode(gf, JOINT_STEREO); break;
                case 'f': lame_set_mode(gf, JOINT_STEREO); break; /* forced MS */
                case 'd': lame_set_mode(gf, DUAL_CHANNEL); break;
                case 'm': case 'l': case 'r': lame_set_mode(gf, MONO); break;
                }
            } else if(strcmp(p, "--lowpass") == 0) {
                p = strtok(NULL, " \t"); if(!p) break;
                lame_set_lowpassfreq(gf, atoi(p));
            }
            p = strtok(NULL, " \t");
        }
        free(buf);
    }

    if(lame_init_params(gf) < 0)
    {
        ctl->cmsg(CMSG_ERROR, VERB_NORMAL,
            "lame_a: lame_init_params failed");
        lame_close(gf);
        gf = NULL;
        if(fd != 1) close(fd);
        return -1;
    }

    dpm.fd = fd;
    return 0;
}

static int auto_lame_output_open(const char *input_filename)
{
    char *output_filename;

#if !defined(IA_W32GUI) && !defined(IA_W32G_SYN)
    output_filename = create_auto_output_name(
        input_filename, "mp3", NULL, 0);
#else
    output_filename = create_auto_output_name(
        input_filename, "mp3",
        (char *)w32g_output_dir, w32g_auto_output_mode);
#endif
    if(output_filename == NULL)
        return -1;
    if(lame_output_open(output_filename) == -1)
    {
        free(output_filename);
        return -1;
    }
    if(dpm.name != NULL)
    {
        free(dpm.name);
        dpm.name = NULL;
    }
    dpm.name = output_filename;
    ctl->cmsg(CMSG_INFO, VERB_NORMAL, "Output %s", dpm.name);
    return 0;
}

static int open_output(void)
{
    int include_enc, exclude_enc;

    include_enc = exclude_enc = 0;
    if(dpm.encoding & PE_24BIT) {
        exclude_enc |= PE_24BIT;
        include_enc |= PE_16BIT;
    }
    if(dpm.encoding & PE_16BIT || dpm.encoding & PE_24BIT) {
#ifdef LITTLE_ENDIAN
        exclude_enc |= PE_BYTESWAP;
#else
        include_enc |= PE_BYTESWAP;
#endif
        include_enc |= PE_SIGNED;
    } else {
        exclude_enc |= PE_SIGNED;
    }

    dpm.encoding = validate_encoding(dpm.encoding,
        include_enc, exclude_enc);

#if !defined(IA_W32GUI) && !defined(IA_W32G_SYN)
    if(dpm.name == NULL) {
        dpm.flag |= PF_AUTO_SPLIT_FILE;
    } else {
        dpm.flag &= ~PF_AUTO_SPLIT_FILE;
        if(lame_output_open(dpm.name) == -1)
            return -1;
    }
#else
    if(w32g_auto_output_mode > 0) {
        dpm.flag |= PF_AUTO_SPLIT_FILE;
        dpm.name = NULL;
    } else {
        dpm.flag &= ~PF_AUTO_SPLIT_FILE;
        if(lame_output_open(dpm.name) == -1)
            return -1;
    }
#endif

    return 0;
}

static int output_data(char *buf, int32 nbytes)
{
    int nch, nsamples, mp3bytes;

    if(dpm.fd < 0 || gf == NULL)
        return 0;

    nch = (dpm.encoding & PE_MONO) ? 1 : 2;
    nsamples = nbytes / (2 * nch);

    if(nsamples <= 0)
        return 0;

    mp3bytes = lame_encode_buffer_interleaved(
        gf, (short int *)buf, nsamples, mp3buf, sizeof(mp3buf));

    if(mp3bytes < 0) {
        ctl->cmsg(CMSG_ERROR, VERB_NORMAL,
            "lame_a: encode failed (%d)", mp3bytes);
        return -1;
    }

    if(mp3bytes > 0) {
        if(std_write(dpm.fd, mp3buf, mp3bytes) != mp3bytes)
            return -1;
    }

    return 0;
}

static void close_output(void)
{
    int mp3bytes;

    if(dpm.fd < 0)
        return;

    if(gf != NULL) {
        mp3bytes = lame_encode_flush(gf, mp3buf, sizeof(mp3buf));
        if(mp3bytes > 0)
            std_write(dpm.fd, mp3buf, mp3bytes);
        lame_close(gf);
        gf = NULL;
    }

    close(dpm.fd);
    dpm.fd = -1;
}

static int acntl(int request, void *arg)
{
    switch(request)
    {
    case PM_REQ_PLAY_START:
        if(dpm.flag & PF_AUTO_SPLIT_FILE)
        {
            return auto_lame_output_open(
                (current_file_info && current_file_info->filename)
                ? current_file_info->filename : "Output.mid");
        }
        return 0;
    case PM_REQ_PLAY_END:
        if(dpm.flag & PF_AUTO_SPLIT_FILE)
            close_output();
        return 0;
    case PM_REQ_DISCARD:
        return 0;
    case PM_REQ_FLUSH:
    case PM_REQ_OUTPUT_FINISH:
    default:
        return 0;
    }
}
