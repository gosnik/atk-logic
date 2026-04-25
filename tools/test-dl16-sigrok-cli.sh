#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LIBSIGROK_DIR="${LIBSIGROK_DIR:-$ROOT_DIR/libsigrok}"
SIGROK_CLI_DIR="${SIGROK_CLI_DIR:-$ROOT_DIR/sigrok-cli}"
PREFIX_DIR="${PREFIX_DIR:-$ROOT_DIR/.sigrok-local}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
SAMPLERATE="${SAMPLERATE:-100m}"
SAMPLES="${SAMPLES:-100000}"
OUTPUT_FILE="${OUTPUT_FILE:-$ROOT_DIR/dl16-smoke.bin}"
CONTINUOUS="${CONTINUOUS:-off}"
RLE="${RLE:-off}"
MODE="${1:-all}"

export PKG_CONFIG_PATH="$PREFIX_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export CPPFLAGS="-I$PREFIX_DIR/include ${CPPFLAGS:-}"
export LDFLAGS="-L$PREFIX_DIR/lib ${LDFLAGS:-}"
export LD_LIBRARY_PATH="$PREFIX_DIR/lib:${LD_LIBRARY_PATH:-}"
export PATH="$PREFIX_DIR/bin:$PATH"

clean_autotools_tree() {
  local dir="$1"

  pushd "$dir" >/dev/null
  if [[ -f Makefile ]]; then
    make distclean >/dev/null 2>&1 || true
  fi
  popd >/dev/null
}

build_libsigrok() {
  echo "[libsigrok] building into $PREFIX_DIR"
  pushd "$LIBSIGROK_DIR" >/dev/null
  clean_autotools_tree "$LIBSIGROK_DIR"
  ./autogen.sh
  ./configure \
    --prefix="$PREFIX_DIR" \
    --disable-shared \
    --enable-static \
    --disable-bindings
  make -j"$BUILD_JOBS"
  make install
  popd >/dev/null
}

ensure_sigrok_cli_repo() {
  if [[ -d "$SIGROK_CLI_DIR/.git" ]]; then
    return
  fi

  echo "[sigrok-cli] cloning latest repository"
  git clone https://github.com/sigrokproject/sigrok-cli.git "$SIGROK_CLI_DIR"
}

build_sigrok_cli() {
  ensure_sigrok_cli_repo
  echo "[sigrok-cli] building against local libsigrok in $PREFIX_DIR"
  pushd "$SIGROK_CLI_DIR" >/dev/null
  clean_autotools_tree "$SIGROK_CLI_DIR"
  ./autogen.sh
  PKG_CONFIG="pkg-config --static" \
  ./configure \
    --prefix="$PREFIX_DIR" \
    --without-libsigrokdecode
  make -j"$BUILD_JOBS"
  make install
  popd >/dev/null
}

scan_dl16() {
  echo "[scan] sigrok-cli version"
  sigrok-cli --version
  echo "[scan] looking for ALIENTEK DL16"
  sigrok-cli --scan | tee "$ROOT_DIR/dl16-scan.log"
}

capture_dl16() {
  echo "[capture] samplerate=$SAMPLERATE continuous=$CONTINUOUS rle=$RLE samples=$SAMPLES output=$OUTPUT_FILE"
  rm -f "$OUTPUT_FILE"
  sigrok-cli \
    --driver alientek-dl16 \
    --config "samplerate=$SAMPLERATE" \
    --config "continuous=$CONTINUOUS" \
    --config "rle=$RLE" \
    --samples "$SAMPLES" \
    --output-file "$OUTPUT_FILE" \
    --output-format binary
  ls -lh "$OUTPUT_FILE"
}

case "$MODE" in
  build-libsigrok)
    build_libsigrok
    ;;
  build-sigrok-cli)
    build_libsigrok
    build_sigrok_cli
    ;;
  scan)
    build_libsigrok
    build_sigrok_cli
    scan_dl16
    ;;
  capture)
    build_libsigrok
    build_sigrok_cli
    capture_dl16
    ;;
  all)
    build_libsigrok
    build_sigrok_cli
    scan_dl16
    capture_dl16
    ;;
  *)
    echo "usage: $0 [build-libsigrok|build-sigrok-cli|scan|capture|all]" >&2
    exit 2
    ;;
esac
