#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build/appimage}"
BUILD_DIR="${BUILD_DIR:-$BUILD_ROOT/atk-logic-build}"
APPDIR="${APPDIR:-$BUILD_ROOT/ATK-LogicView.AppDir}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
TOOLS_DIR="${TOOLS_DIR:-$BUILD_ROOT/tools}"
QT_PRIVATE_ROOT="${QT_PRIVATE_ROOT:-$TOOLS_DIR/qtbase5-private-dev}"
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
VERSION="${VERSION:-$(sed -n 's/^VERSION *= *//p' "$ROOT_DIR/ATK-Logic.pro" | head -1)}"
ARCH_NAME="${ARCH_NAME:-x86_64}"
OUTPUT_NAME="${OUTPUT_NAME:-ATK-LogicView-${VERSION}-${ARCH_NAME}.AppImage}"

LINUXDEPLOY_URL="${LINUXDEPLOY_URL:-https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH_NAME}.AppImage}"
QT_PLUGIN_URL="${QT_PLUGIN_URL:-https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-${ARCH_NAME}.AppImage}"

export APPIMAGE_EXTRACT_AND_RUN="${APPIMAGE_EXTRACT_AND_RUN:-1}"

download_tool() {
  local url="$1"
  local output="$2"

  if [[ -x "$output" ]]; then
    return
  fi

  mkdir -p "$(dirname -- "$output")"
  echo "[tools] downloading $(basename -- "$output")"
  curl -L --fail --retry 3 --output "$output" "$url"
  chmod +x "$output"
}

ensure_qt_private_headers() {
  if find /usr/include /usr/lib -path '*/QtGui/private/qzipreader_p.h' -print -quit 2>/dev/null | grep -q .; then
    return
  fi

  if [[ -f "$QT_PRIVATE_ROOT/usr/include/x86_64-linux-gnu/qt5/QtGui/5.15.13/QtGui/private/qzipreader_p.h" ]]; then
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "qtbase5-private-dev is required for qzipreader_p.h. Install it or provide QT_PRIVATE_ROOT." >&2
    exit 1
  fi

  echo "[tools] extracting qtbase5-private-dev headers into $QT_PRIVATE_ROOT"
  mkdir -p "$TOOLS_DIR/apt" "$QT_PRIVATE_ROOT"
  pushd "$TOOLS_DIR/apt" >/dev/null
  rm -f qtbase5-private-dev_*.deb
  apt-get download qtbase5-private-dev
  dpkg-deb -x qtbase5-private-dev_*.deb "$QT_PRIVATE_ROOT"
  popd >/dev/null
}

qt_private_include_paths() {
  if [[ -d "$QT_PRIVATE_ROOT/usr/include" ]]; then
    find "$QT_PRIVATE_ROOT/usr/include" -type d -path '*/qt5/Qt*/5.*' -print | sort | paste -sd' ' -
  fi
}

find_atk_binary() {
  local candidate

  for candidate in \
    "$BUILD_DIR/ATK-Logic" \
    "$BUILD_DIR/release/ATK-Logic" \
    "$BUILD_DIR/Release/ATK-Logic"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  find "$BUILD_DIR" -maxdepth 3 -type f -name ATK-Logic -perm -111 -print -quit
}

prepare_static_decoder_lib() {
  local lib="$ROOT_DIR/libsigrokdecode.a"

  if [[ ! -f "$lib" && -f "$ROOT_DIR/atk_libsigrokdecode/.libs/libsigrokdecode.a" ]]; then
    lib="$ROOT_DIR/atk_libsigrokdecode/.libs/libsigrokdecode.a"
  fi

  if [[ ! -f "$lib" ]]; then
    echo "libsigrokdecode.a was not found. Build or copy it into the repo root first." >&2
    exit 1
  fi

  cp "$lib" "$BUILD_DIR/libsigrokdecode.a"
}

build_atk_logic() {
  local include_paths

  echo "[build] configuring ATK-Logic in $BUILD_DIR"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  prepare_static_decoder_lib
  ensure_qt_private_headers
  include_paths="$(qt_private_include_paths)"

  pushd "$BUILD_DIR" >/dev/null
  if [[ -n "$include_paths" ]]; then
    qmake "$ROOT_DIR/ATK-Logic.pro" CONFIG+=release CONFIG-=debug "INCLUDEPATH+=$include_paths"
  else
    qmake "$ROOT_DIR/ATK-Logic.pro" CONFIG+=release CONFIG-=debug
  fi
  make -j"$BUILD_JOBS"
  popd >/dev/null
}

prepare_icon() {
  local source_icon="$ROOT_DIR/resource/icon/icon.png"
  local output_icon="$BUILD_ROOT/ATK-LogicView.png"

  if [[ ! -f "$source_icon" ]]; then
    source_icon="$ROOT_DIR/img/logo.png"
  fi

  if [[ ! -f "$source_icon" ]]; then
    echo "No ATK-Logic icon found." >&2
    exit 1
  fi

  if ! command -v convert >/dev/null 2>&1; then
    echo "ImageMagick convert is required to create a valid 256x256 AppImage icon." >&2
    exit 1
  fi

  convert "$source_icon" -resize 256x256 -background transparent -gravity center -extent 256x256 "$output_icon"
  printf '%s\n' "$output_icon"
}

write_desktop_file() {
  local desktop="$BUILD_ROOT/ATK-LogicView.desktop"

  cat >"$desktop" <<EOF_DESKTOP
[Desktop Entry]
Name=ATK LogicView
GenericName=Logic analyzer GUI
Comment=Control ALIENTEK logic analyzer devices
Exec=ATK-Logic
Icon=ATK-LogicView
Type=Application
Categories=Development;Electronics;
EOF_DESKTOP

  printf '%s\n' "$desktop"
}

prepare_appdir() {
  local binary="$1"

  echo "[appdir] preparing $APPDIR"
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr/bin"

  cp "$binary" "$APPDIR/usr/bin/ATK-Logic"
  cp -a "$ROOT_DIR/runtime/decoders" "$APPDIR/usr/bin/decoders"

  if compgen -G "$ROOT_DIR/runtime/ATK-Logic*.pdf" >/dev/null; then
    cp -a "$ROOT_DIR"/runtime/ATK-Logic*.pdf "$APPDIR/usr/bin/"
  fi
}

build_appimage() {
  local binary="$1"
  local desktop="$2"
  local icon
  local linuxdeploy="$TOOLS_DIR/linuxdeploy-${ARCH_NAME}.AppImage"
  local qt_plugin="$TOOLS_DIR/linuxdeploy-plugin-qt-${ARCH_NAME}.AppImage"

  icon="$(prepare_icon)"

  download_tool "$LINUXDEPLOY_URL" "$linuxdeploy"
  download_tool "$QT_PLUGIN_URL" "$qt_plugin"

  rm -f "$ROOT_DIR/$OUTPUT_NAME" "$DIST_DIR/$OUTPUT_NAME"
  mkdir -p "$DIST_DIR"

  echo "[appimage] building $OUTPUT_NAME"
  export LDAI_OUTPUT="$OUTPUT_NAME"
  export QML_SOURCES_PATHS="$ROOT_DIR/qml"
  export EXTRA_QT_PLUGINS="${EXTRA_QT_PLUGINS:-platformthemes/libqgtk3.so}"

  pushd "$ROOT_DIR" >/dev/null
  "$linuxdeploy" \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/ATK-Logic" \
    --desktop-file "$desktop" \
    --icon-file "$icon" \
    --plugin qt \
    --output appimage
  popd >/dev/null

  mv "$ROOT_DIR/$OUTPUT_NAME" "$DIST_DIR/$OUTPUT_NAME"
  echo "[appimage] wrote $DIST_DIR/$OUTPUT_NAME"
}

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  build_atk_logic
else
  echo "[build] reusing existing ATK-Logic build from $BUILD_DIR"
fi

ATK_BINARY="$(find_atk_binary)"
if [[ -z "$ATK_BINARY" ]]; then
  echo "ATK-Logic build completed but no executable was found under $BUILD_DIR." >&2
  exit 1
fi

prepare_appdir "$ATK_BINARY"
DESKTOP_FILE="$(write_desktop_file)"
build_appimage "$ATK_BINARY" "$DESKTOP_FILE"
