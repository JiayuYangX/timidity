#!/bin/bash
# TiMidity++ 32-bit build script
# Usage: ./build.sh [OUTDIR] [gui|cli|synth|service|all]

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
        gui|cli|synth|service|all) TARGET="$arg" ;;
        *) echo "Usage: $0 [OUTDIR] [gui|cli|synth|service|driver|all]"; exit 1 ;;
    esac
done

CONFIGURE_OPTS="--build=x86_64-w64-mingw32 --host=i686-w64-mingw32 --prefix="
AUDIO_OPTS="--enable-audio=w32,vorbis,gogo,ogg,flac,portaudio,lame"
GUI_OPTS="--enable-network --enable-w32gui"
CONSOLE_OPTS="--enable-ncurses --enable-vt100 --enable-winsyn --enable-network --with-ncurses=/mingw32"
SYNTH_OPTS="--enable-network --enable-winsyng"
#DRV_OPTS="--enable-winsyn --enable-windrv"
#DRV_AUDIO="--enable-audio=w32,portaudio"

export lib_cv_va_copy=yes lib_cv___va_copy=yes lib_cv_va_val_copy=yes ac_cv_c_const=yes

build_cli() {
    echo "=== Building CLI ==="
    ./configure $CONFIGURE_OPTS $CONSOLE_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timidity.exe"
    echo "CLI: $(ls -la "$OUTDIR/timidity.exe" | awk '{print $5}')"
}

build_gui() {
    echo "=== Building GUI ==="
    ./configure $CONFIGURE_OPTS $GUI_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timw32g.exe"
    echo "GUI: $(ls -la "$OUTDIR/timw32g.exe" | awk '{print $5}')"
}

build_synth() {
    echo "=== Building synth ==="
    ./configure $CONFIGURE_OPTS $SYNTH_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/twsyng.exe"
    echo "synth: $(ls -la "$OUTDIR/twsyng.exe")"
}

build_service() {
    echo "=== Building service ==="
    ./configure $CONFIGURE_OPTS $SYNTH_OPTS $AUDIO_OPTS
    echo '#define TWSYNSRV 1' >> config.h
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/twsynsrv.exe"
    sed -i '/^#define TWSYNSRV 1$/ d' config.h
    echo "service: $(ls -la "$OUTDIR/twsynsrv.exe")"
}

# build_driver() disabled: WinMM Drivers32 enumeration deprecated on Win10 1903+
#build_driver() {
#    echo "=== Building driver ==="
#    ./configure $CONFIGURE_OPTS $DRV_OPTS $DRV_AUDIO
#    for d in utils libarc libunimod interface timidity; do
#        make -C $d clean 2>/dev/null; make -C $d -j4
#    done
#    make -C windrv clean 2>/dev/null; make -C windrv -j4 && \
#    strip windrv/timiditydrv.dll && \
#    cp windrv/timiditydrv.dll "$OUTDIR/timiditydrv.dll" && \
#    cp windrv/timiditydrv.inf "$OUTDIR/timiditydrv.inf"
#    echo "driver: $(ls -la "$OUTDIR/timiditydrv.dll")"
#}

mkdir -p "$OUTDIR"

case "$TARGET" in
    gui)      build_gui ;;
    cli)      build_cli ;;
    synth)    build_synth ;;
    service)  build_service ;;
#    driver)   build_driver ;;
    all)      build_gui; build_cli; build_synth; build_service ;;
esac
