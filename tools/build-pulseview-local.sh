#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX_DIR="${PREFIX_DIR:-$ROOT_DIR/.sigrok-local}"
LIBSIGROK_DIR="${LIBSIGROK_DIR:-$ROOT_DIR/libsigrok}"
PULSEVIEW_DIR="${PULSEVIEW_DIR:-$ROOT_DIR/pulseview}"
PULSEVIEW_BUILD_DIR="${PULSEVIEW_BUILD_DIR:-$PULSEVIEW_DIR/build-local}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"

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
  echo "[libsigrok] building shared libraries and C++ bindings into $PREFIX_DIR"
  pushd "$LIBSIGROK_DIR" >/dev/null
  clean_autotools_tree "$LIBSIGROK_DIR"
  ./autogen.sh
  ./configure --prefix="$PREFIX_DIR"
  make -j"$BUILD_JOBS"
  make install
  popd >/dev/null
}

configure_pulseview() {
  echo "[pulseview] configuring in $PULSEVIEW_BUILD_DIR"
  rm -rf "$PULSEVIEW_BUILD_DIR"
  cmake -S "$PULSEVIEW_DIR" -B "$PULSEVIEW_BUILD_DIR" \
    -DCMAKE_PREFIX_PATH="$PREFIX_DIR" \
    -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=ON \
    -DCMAKE_BUILD_RPATH="$PREFIX_DIR/lib" \
    -DCMAKE_INSTALL_RPATH="$PREFIX_DIR/lib"
}

build_pulseview() {
  echo "[pulseview] building"
  cmake --build "$PULSEVIEW_BUILD_DIR" -j"$BUILD_JOBS"
}

show_run_hint() {
  echo
  echo "PulseView binary:"
  echo "  $PULSEVIEW_BUILD_DIR/pulseview"
  echo
  echo "Run it with:"
  echo "  LD_LIBRARY_PATH=\"$PREFIX_DIR/lib:\$LD_LIBRARY_PATH\" \"$PULSEVIEW_BUILD_DIR/pulseview\""
}

build_libsigrok
configure_pulseview
build_pulseview
show_run_hint
