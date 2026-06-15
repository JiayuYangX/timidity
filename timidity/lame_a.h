/*
    TiMidity++ -- MIDI to WAVE converter and player
    Copyright (C) 1999-2004 Masanao Izumo <mo@goice.co.jp>
    Copyright (C) 1995 Tuukka Toivonen <tt@cgs.fi>

    lame_a.h

    LAME MP3 encoder config
*/

#ifndef __LAME_A_H__
#define __LAME_A_H__

/* limited to match GOGO's max */
#define LAME_MAX_TAG_OPTIONS 64

typedef struct lame_ConfigDialogInfo_t_ {
    int optIDC_CHECK_DEFAULT;
    int optIDC_CHECK_VBR;
    int optIDC_COMBO_VBR_QUALITY;
    int optIDC_COMBO_CBR_BITRATE;
    int optIDC_CHECK_ENCODE_MODE;
    int optIDC_COMBO_ENCODE_MODE;
    int optIDC_CHECK_ALGO_QUALITY;
    int optIDC_COMBO_ALGO_QUALITY;
    int optIDC_CHECK_LOWPASS;
    char optIDC_EDIT_LOWPASS[8];
    int optIDC_CHECK_COMMANDLINE_OPTS;
    char optIDC_EDIT_COMMANDLINE_OPTION[1024];
    int optOutputFormat;
    char optOutputDir[1024];
} lame_ConfigDialogInfo_t;

extern volatile lame_ConfigDialogInfo_t lame_ConfigDialogInfo;
extern int lame_ConfigDialogInfo_initialized;

extern int lame_ConfigDialogInfoInit(void);
extern int lame_ConfigDialogInfoApply(void);
extern int lame_ConfigDialogInfoSaveINI(void);
extern int lame_ConfigDialogInfoLoadINI(void);

#endif /* __LAME_A_H__ */
