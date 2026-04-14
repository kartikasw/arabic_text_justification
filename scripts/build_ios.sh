#!/usr/bin/env bash
set -euo pipefail

# Builds a static XCFramework with device (arm64) and simulator (arm64 + x86_64)
# slices, then writes it to ios/Frameworks/arabic_text_justification.xcframework
# for the podspec to pick up as a vendored_framework.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/ios"
OUT="$ROOT/ios/Frameworks"
FW_NAME="arabic_text_justification"
MIN_IOS="12.0"

CMAKE="${CMAKE:-cmake}"
if ! command -v "$CMAKE" >/dev/null 2>&1; then
  # Fall back to Android SDK cmake if system cmake is missing.
  CMAKE="$HOME/Library/Android/sdk/cmake/3.22.1/bin/cmake"
fi

if [ ! -d "$ROOT/third_party/harfbuzz/src" ] || [ ! -d "$ROOT/third_party/freetype/src" ]; then
  echo "Submodules not initialized. Running: git submodule update --init --recursive"
  git -C "$ROOT" submodule update --init --recursive
fi

rm -rf "$BUILD" "$OUT/$FW_NAME.xcframework"
mkdir -p "$OUT"

build_slice() {
  local SLICE_NAME="$1"       # e.g. ios-arm64
  local SYSROOT="$2"          # iphoneos | iphonesimulator
  local ARCHS="$3"            # e.g. arm64 or "arm64;x86_64"

  local BDIR="$BUILD/$SLICE_NAME"
  mkdir -p "$BDIR"

  local SYSROOT_PATH
  SYSROOT_PATH=$(xcrun --sdk "$SYSROOT" --show-sdk-path)

  echo "==> Configuring $SLICE_NAME (sdk=$SYSROOT archs=$ARCHS)"
  "$CMAKE" -S "$ROOT/native/ios" -B "$BDIR" -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SYSROOT_PATH" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_IOS_INSTALL_COMBINED=NO

  echo "==> Building $SLICE_NAME"
  "$CMAKE" --build "$BDIR" --parallel

  # Merge all static libs into one self-contained archive using libtool.
  local LIBS=(
    "$BDIR/libarabic_text_justification.a"
    "$BDIR/harfbuzz_build/libharfbuzz.a"
    "$BDIR/freetype_build/libfreetype.a"
  )
  local MERGED="$BDIR/lib${FW_NAME}_merged.a"
  rm -f "$MERGED"
  xcrun libtool -static -o "$MERGED" "${LIBS[@]}"

  echo "    -> $MERGED"
}

build_slice "ios-arm64" "iphoneos" "arm64"
build_slice "ios-simulator" "iphonesimulator" "arm64"

echo "==> Creating XCFramework"
xcodebuild -create-xcframework \
  -library "$BUILD/ios-arm64/lib${FW_NAME}_merged.a" \
  -library "$BUILD/ios-simulator/lib${FW_NAME}_merged.a" \
  -output "$OUT/$FW_NAME.xcframework"

echo "Done. XCFramework at $OUT/$FW_NAME.xcframework"
