/*
    TiMidity++ -- MIDI to WAVE converter and player
    Copyright (C) 1999-2004 Masanao Izumo <mo@goice.co.jp>
    Copyright (C) 1995 Tuukka Toivonen <tt@cgs.fi>

    asio_a.h

    ASIO output device selection config
*/

#ifndef __ASIO_A_H__
#define __ASIO_A_H__

typedef struct {
    int device_index; /* -1 = default, >=0 = specific device */
} AsioConfigDialogInfo_t;

extern volatile AsioConfigDialogInfo_t asio_ConfigDialogInfo;
extern int asio_ConfigDialogInfo_initialized;

extern int asio_ConfigDialogInfoInit(void);
extern int asio_ConfigDialogInfoSaveINI(void);
extern int asio_ConfigDialogInfoLoadINI(void);

#endif /* __ASIO_A_H__ */
