#!/bin/bash
# TiMidity++ 32-bit build script
# Usage: ./build.sh [OUTDIR] [console|gui|all]
#    或: ./build.sh [console|gui|all] [OUTDIR]
#    ./build.sh              # both, default dir
#    ./build.sh /e/out       # both, custom dir
#    ./build.sh /e/out gui   # GUI, custom dir
#    ./build.sh gui /e/out   # same

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
AUDIO_OPTS="--enable-audio=w32,vorbis,gogo,ogg,flac,portaudio"
GUI_OPTS="--enable-network --enable-w32gui"
CONSOLE_OPTS="--enable-ncurses --enable-vt100 --enable-winsyn --enable-network --with-ncurses=/mingw32"

export lib_cv_va_copy=yes lib_cv___va_copy=yes lib_cv_va_val_copy=yes ac_cv_c_const=yes
export CFLAGS="-std=gnu89 -O2 -Wno-incompatible-pointer-types"

patch_makefiles() {
    local gui=$1
    cd timidity
    sed -i 's/-DAU_VORBIS_DLL //;s/-DAU_PORTAUDIO_DLL //;s/-DAU_FLAC_DLL //' Makefile
    sed -i 's/-DAU_FLAC /-DAU_FLAC -DFLAC__NO_DLL -DNCURSES_STATIC /' Makefile

    if [ "$gui" = "yes" ]; then
        sed -i 's/^LDFLAGS = .*$/LDFLAGS =  -mwindows -L\/lib -static -static-libgcc -Wl,--allow-multiple-definition/' Makefile
        sed -i 's/^LIBS = .*$/LIBS = -lm  -lncursesw    -luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lole32  -lws2_32 -lportaudio -lwinmm -lole32 -L\/lib -lvorbis -lm -lvorbisenc -L\/lib -lFLAC -logg -lsetupapi -loleaut32 -lstdc++/' Makefile
    else
        sed -i 's/^LDFLAGS = .*$/LDFLAGS =  -L\/lib -static -static-libgcc -Wl,--allow-multiple-definition/' Makefile
        sed -i 's/^LIBS = .*$/LIBS = -lm  -lncursesw       -lws2_32 -lportaudio -lwinmm -lole32 -L\/lib -lvorbis -lm -lvorbisenc -L\/lib -lFLAC -logg -lsetupapi -loleaut32 -lstdc++/' Makefile
    fi

    cd ../interface
    sed -i 's/-DAU_VORBIS_DLL //;s/-DAU_PORTAUDIO_DLL //;s/-DAU_FLAC_DLL //' Makefile
    sed -i 's/ -DAU_GOGO / -DNCURSES_STATIC -DAU_GOGO /' Makefile
    rm -f *.o libinterface.a
    make -j4
    cd ..
}

build_console() {
    echo "=== Building console ==="
    ./configure $CONFIGURE_OPTS $CONSOLE_OPTS $AUDIO_OPTS
    patch_makefiles "no"
    cd timidity
    rm -f portaudio_a.o output.o timidity.exe
    make -j4
    strip timidity.exe
    cp timidity.exe "$OUTDIR/timidity.exe"
    cd ..
    echo "Console: $(ls -la "$OUTDIR/timidity.exe" | awk '{print $5}')"
}

build_gui() {
    echo "=== Building GUI ==="
    ./configure $CONFIGURE_OPTS $GUI_OPTS $AUDIO_OPTS
    patch_makefiles "yes"
    cd timidity
    rm -f portaudio_a.o output.o timidity.exe
    make -j4
    strip timidity.exe
    cp timidity.exe "$OUTDIR/timw32g.exe"
    cd ..
    echo "GUI: $(ls -la "$OUTDIR/timw32g.exe" | awk '{print $5}')"
}

mkdir -p "$OUTDIR"

case "$TARGET" in
    console) build_console ;;
    gui)     build_gui ;;
    all)     build_gui; build_console ;;
esac
