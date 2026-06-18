#!/bin/bash
# TiMidity++ 32-bit build script
# Usage: ./build.sh [OUTDIR] [console|gui|all]

set -e
export PATH=/mingw32/bin:/ucrt64/bin:/usr/bin

cd "$(dirname "$0")"
SRCDIR="$(pwd)"
OUTDIR="$SRCDIR"
TARGET=all

for arg in "$@"; do
    case "$arg" in
        [a-zA-Z]:[/\\]*) OUTDIR="$(echo "$arg" | sed 's|\\|/|g; s|^\([a-zA-Z]\):|/\L\1|')" ;;
        /*) OUTDIR="$arg" ;;
        console|gui|all) TARGET="$arg" ;;
        *) echo "Usage: $0 [OUTDIR] [console|gui|all]"; exit 1 ;;
    esac
done

CONFIGURE_OPTS="--build=x86_64-w64-mingw32 --host=i686-w64-mingw32 --prefix="
AUDIO_OPTS="--enable-audio=w32,vorbis,gogo,ogg,flac,portaudio,lame"
GUI_OPTS="--enable-network --enable-w32gui"
CONSOLE_OPTS="--enable-ncurses --enable-vt100 --enable-winsyn --enable-network --with-ncurses=/mingw32"

export lib_cv_va_copy=yes lib_cv___va_copy=yes lib_cv_va_val_copy=yes ac_cv_c_const=yes

build_console() {
    echo "=== Building console ==="
    ./configure $CONFIGURE_OPTS $CONSOLE_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timidity.exe"
    echo "Console: $(ls -la "$OUTDIR/timidity.exe" | awk '{print $5}')"
}

build_gui() {
    echo "=== Building GUI ==="
    ./configure $CONFIGURE_OPTS $GUI_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timw32g.exe"
    echo "GUI: $(ls -la "$OUTDIR/timw32g.exe" | awk '{print $5}')"
}

mkdir -p "$OUTDIR"

case "$TARGET" in
    console) build_console ;;
    gui)     build_gui ;;
    all)     build_gui; build_console ;;
esac
