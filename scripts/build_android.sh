#!/usr/bin/env bash
set -euo pipefail

NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/25.1.8937393}"
SDK_CMAKE="${ANDROID_SDK_CMAKE:-$HOME/Library/Android/sdk/cmake/3.22.1}"
CMAKE="${CMAKE:-$SDK_CMAKE/bin/cmake}"
NINJA="${NINJA:-$SDK_CMAKE/bin/ninja}"
MIN_SDK=21
ABIS=("arm64-v8a" "x86_64")

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/android/src/main/jniLibs"
BUILD="$ROOT/.build/android"

if [ ! -d "$NDK" ]; then
  echo "NDK not found at $NDK" >&2
  echo "Set ANDROID_NDK env var to a valid NDK path." >&2
  exit 1
fi

HOST_TAG="darwin-x86_64"
STRIP="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-strip"

if [ ! -d "$ROOT/third_party/harfbuzz/src" ] || [ ! -d "$ROOT/third_party/freetype/src" ]; then
  echo "Submodules not initialized. Running: git submodule update --init --recursive"
  git -C "$ROOT" submodule update --init --recursive
fi

rm -rf "$BUILD"
mkdir -p "$OUT"

for ABI in "${ABIS[@]}"; do
  echo "==> Building $ABI"
  BDIR="$BUILD/$ABI"
  mkdir -p "$BDIR"

  "$CMAKE" -S "$ROOT/native" -B "$BDIR" -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="android-$MIN_SDK" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,--exclude-libs,ALL"

  "$CMAKE" --build "$BDIR" --parallel

  mkdir -p "$OUT/$ABI"
  cp "$BDIR/libarabic_text_justification.so" "$OUT/$ABI/"
  "$STRIP" --strip-unneeded "$OUT/$ABI/libarabic_text_justification.so"
  SIZE=$(du -h "$OUT/$ABI/libarabic_text_justification.so" | cut -f1)
  echo "    -> $OUT/$ABI/libarabic_text_justification.so ($SIZE)"
done

echo "Done. Prebuilt libraries written to $OUT"
