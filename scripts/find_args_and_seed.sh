#!/bin/sh
# ENV
# -- BIN

. $(dirname $0)/common.sh

# AFL_MAP_SIZE for aflplusplus.
# By default it 65536, but some programs nees adjustment.
AFL_MAP_SIZE=65536

# It is the size of branch counting AFL/AFL++/Angora uses.
# It's measured in the number of shifts. By default it is
# 16, i.e. 1 << 16 = 64K for AFL/AFL++; 20, i.e. 1M for Angora.
BR_COUNT_BUF_SIZE=16

case $BIN in
"exiv2")

  ARGS="@@"
  PACKAGE="exiv2 0.26"
  SEED_CATEGORY="jpg"
  ;;

"imginfo")

  ARGS="-f @@"
  PACKAGE="jasper-2.0.12"
  SEED_CATEGORY="imginfo"
  BR_COUNT_BUF_SIZE=16
  ;;

"pdftotext")

  ARGS="@@"
  PACKAGE="xpdf-4.00"
  SEED_CATEGORY="pdf"
  BR_COUNT_BUF_SIZE=18
  ;;

"tiffsplit")

  ARGS="@@"
  PACKAGE="tiff-4.2.0"
  SEED_CATEGORY="tiff"
  BR_COUNT_BUF_SIZE=19
  ;;

"tiff2ps")

  ARGS="@@"
  PACKAGE="tiff-4.2.0"
  SEED_CATEGORY="tiff"
  ;;

"tiffcp")

  ARGS="-M @@ /tmp/tmp.out"
  PACKAGE="tiff-4.2.0"
  SEED_CATEGORY="tiff"
  ;;

"nm")

  ARGS="-C @@"
  PACKAGE="binutils-2.35"
  SEED_CATEGORY="obj"
  BR_COUNT_BUF_SIZE=20
  ;;

"objdump")

  ARGS="-x @@"
  PACKAGE="binutils-2.35"
  SEED_CATEGORY="obj"
  AFL_MAP_SIZE=67584
  BR_COUNT_BUF_SIZE=20
  ;;

"readelf")

  ARGS="-a @@"
  PACKAGE="binutils-2.35"
  SEED_CATEGORY="obj"
  BR_COUNT_BUF_SIZE=18
  ;;

"size")

  ARGS="@@"
  PACKAGE="binutils-2.35"
  SEED_CATEGORY="obj"
  BR_COUNT_BUF_SIZE=20
  ;;

  # TODO add png seeds
"cjpeg")

  ARGS="@@"
  PACKAGE="jpeg-9d"
  SEED_CATEGORY="bmp"
  BR_COUNT_BUF_SIZE=17
  ;;

"djpeg")

  ARGS="@@"
  PACKAGE="jpeg-9d"
  SEED_CATEGORY="jpg"
  ;;

"xmllint")

  ARGS="@@"
  PACKAGE="libxml2.9.10"
  SEED_CATEGORY="xml"
  AFL_MAP_SIZE=83168
  BR_COUNT_BUF_SIZE=20
  ;;

"jhead")

  ARGS="@@"
  PACKAGE="jhead-3.04"
  SEED_CATEGORY="jpg"
  BR_COUNT_BUF_SIZE=13
  ;;

"tcpdump")

  ARGS="-e -vv -nr @@"
  PACKAGE="libpcap-1.9.1/tcpdump-4.9.3"
  SEED_CATEGORY="pcap"
  BR_COUNT_BUF_SIZE=19
  ;;

  #### libexpat R_2_2_10
"xmlwf")

  ARGS="@@"
  PACKAGE="libexpat-R_2_2_10"
  SEED_CATEGORY="xml"
  ;;

  #### mupdf 1.18
"mutool")

  ARGS="draw @@"
  PACKAGE="mupdf-1.18.0-source"
  SEED_CATEGORY="pdf"
  ;;

  #### libpng 1.6.37
"readpng")

  ARGS="@@"
  PACKAGE="libpng-1.6.37"
  SEED_CATEGORY="png"
  BR_COUNT_BUF_SIZE=17
  ;;

  #### FILE5_39
"file")

  ARGS="-m /d/p/bc/magic.mgc @@"
  PACKAGE="file-FILE5_39"
  SEED_CATEGORY="file"
  ;;

"lame")
  ARGS="@@ /dev/null"
  PACKAGE="lame-3.99.5"
  SEED_CATEGORY="lame"
  ;;
"mp3gain")
  ARGS="@@"
  PACKAGE="mp3gain-1.5.2"
  SEED_CATEGORY="mp3"
  ;;
"wav2swf")
  ARGS="-o /dev/null @@"
  PACKAGE="swftools-0.9.2"
  SEED_CATEGORY="wav"
  ;;
"flvmeta")
  ARGS="@@"
  PACKAGE="flvmeta-1.2.1"
  SEED_CATEGORY="flv"
  ;;
"mp42aac")
  ARGS="@@ /dev/null"
  PACKAGE="Bento4-1.5.1-628"
  SEED_CATEGORY="mp4"
  ;;
"cflow")
  ARGS="@@"
  PACKAGE="cflow-1.6"
  SEED_CATEGORY="cflow"
  ;;
"infotocap")
  ARGS="-o /dev/null @@"
  PACKAGE="ncurses-6.1"
  SEED_CATEGORY="text"
  ;;
"jq")
  ARGS=". @@"
  PACKAGE="jq-1.5"
  SEED_CATEGORY="json"
  ;;
"mujs")
  ARGS="@@"
  PACKAGE="mujs-1.0.2"
  SEED_CATEGORY="mujs"
  ;;
"sqlite3")
  ARGS=""
  PACKAGE="SQLite-3.8.9"
  SEED_CATEGORY="sql"
  ;;

*)
  error "Seem like binary $BIN doesn't exist."
  ;;

esac

SEEDDIR="$UNIFUZZ/seeds/$SEED_CATEGORY"
