#!/bin/bash
# TiMidity++ 32-bit build script
# Usage: ./build.sh [OUTDIR] [gui|cli|synth|service|all] [ENCODING]
#   ENCODING: GBK (default, in-tree), UTF-8, Shift_JIS, or any iconv target

set -e
export PATH=/mingw32/bin:/ucrt64/bin:/usr/bin

cd "$(dirname "$0")"
SRCDIR="$(pwd)"
OUTDIR="$SRCDIR"
TARGET=all
ENCODING=

for arg in "$@"; do
    case "$arg" in
        [a-zA-Z]:[/\\]*) OUTDIR="$(echo "$arg" | sed 's|\\|/|g; s|^\([a-zA-Z]\):|/\L\1|')" ;;
        /*) OUTDIR="$arg" ;;
        gui|cli|synth|service|all) TARGET="$arg" ;;
        *) ENCODING="$arg" ;;
    esac
done

# Pass encoding through for 'all' target
export BUILD_ENCODING="$ENCODING"

CONFIGURE_OPTS="--build=x86_64-w64-mingw32 --host=i686-w64-mingw32 --prefix="
AUDIO_OPTS="--enable-audio=w32,vorbis,gogo,ogg,flac,portaudio,lame"
GUI_OPTS="--enable-network --enable-w32gui"
CLI_OPTS="--enable-ncurses --enable-vt100 --enable-winsyn --enable-network --with-ncurses=/mingw32"
SYNTH_OPTS="--enable-network --enable-winsyng"

export lib_cv_va_copy=yes lib_cv___va_copy=yes lib_cv_va_val_copy=yes ac_cv_c_const=yes

# Files requiring iconv when encoding != GBK
ENCODED_FILES="
interface/w32g_i.c
interface/w32g_pref.c
interface/w32g_subwin.c
interface/w32g_subwin2.c
interface/w32g_subwin3.c
interface/w32g_syn.c
interface/w32g_utl.c
interface/w32g_ut2.c
interface/w32g_c.c
"

build_encoded() {
    local label="$1" cfgs_opts="$2" target_exe="$3" define_extra="$4"
    local enc="${BUILD_ENCODING:-GBK}"
    local tmp="$SRCDIR/_iconv"

    echo "=== Building $label (${enc}) ==="

    rm -rf "$tmp"
    mkdir -p "$tmp"

    # Copy source tree via tar (exclude _iconv to avoid nested copies)
    cd "$SRCDIR"
    tar cf - --exclude='_iconv*' . | (cd "$tmp" && tar xf -)
    cd "$tmp"

    # iconv the 9 files in the copy
    for f in $ENCODED_FILES; do
        if ! iconv -f GBK -t "$enc" "$f" > "$f.tmp" 2>/dev/null; then
            rm "$f.tmp"
        else
            mv "$f.tmp" "$f"
        fi
    done

    # Build
    ./configure $cfgs_opts
    if [ -n "$define_extra" ]; then
        echo "$define_extra" >> config.h
    fi
    make
    local result=$?

    if [ "$result" -eq 0 ]; then
        strip timidity/timidity.exe
        cp timidity/timidity.exe "$OUTDIR/$target_exe"
        echo "$label: $(ls -la "$OUTDIR/$target_exe" | awk '{print $5}')"
    fi

    cd "$SRCDIR"
    rm -rf "$tmp"
    return $result
}

build_gui() {
    if [ -n "$BUILD_ENCODING" ] && [ "$BUILD_ENCODING" != "GBK" ]; then
        build_encoded "GUI" "$CONFIGURE_OPTS $GUI_OPTS $AUDIO_OPTS" "timw32g.exe"
        return
    fi
    echo "=== Building GUI ==="
    ./configure $CONFIGURE_OPTS $GUI_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timw32g.exe"
    echo "GUI: $(ls -la "$OUTDIR/timw32g.exe" | awk '{print $5}')"
}

build_cli() {
    if [ -n "$BUILD_ENCODING" ] && [ "$BUILD_ENCODING" != "GBK" ]; then
        build_encoded "CLI" "$CONFIGURE_OPTS $CLI_OPTS $AUDIO_OPTS" "timidity.exe"
        return
    fi
    echo "=== Building CLI ==="
    ./configure $CONFIGURE_OPTS $CLI_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/timidity.exe"
    echo "CLI: $(ls -la "$OUTDIR/timidity.exe" | awk '{print $5}')"
}

build_synth() {
    if [ -n "$BUILD_ENCODING" ] && [ "$BUILD_ENCODING" != "GBK" ]; then
        build_encoded "synth" "$CONFIGURE_OPTS $SYNTH_OPTS $AUDIO_OPTS" "twsyng.exe"
        return
    fi
    echo "=== Building synth ==="
    ./configure $CONFIGURE_OPTS $SYNTH_OPTS $AUDIO_OPTS
    make clean 2>/dev/null; make -j4 && \
    strip timidity/timidity.exe && \
    cp timidity/timidity.exe "$OUTDIR/twsyng.exe"
    echo "synth: $(ls -la "$OUTDIR/twsyng.exe")"
}

build_service() {
    if [ -n "$BUILD_ENCODING" ] && [ "$BUILD_ENCODING" != "GBK" ]; then
        build_encoded "service" "$CONFIGURE_OPTS $SYNTH_OPTS $AUDIO_OPTS" "twsynsrv.exe" '#define TWSYNSRV 1'
        return
    fi
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
