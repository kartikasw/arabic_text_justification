cmake_minimum_required(VERSION 3.15)
project(arabic_text_justification)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

set(HB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/harfbuzz)
set(FT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/freetype)

set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
# Xcode 26's iOS SDK ships an `hvf/` framework that FreeType auto-detects.
# We don't want a runtime dependency on it — disable the HVF backend.
set(FT_DISABLE_HVF ON CACHE BOOL "" FORCE)
add_subdirectory(${FT_ROOT} freetype_build)

set(HB_HAVE_FREETYPE ON CACHE BOOL "" FORCE)
add_subdirectory(${HB_ROOT} harfbuzz_build)

# Static library for iOS — CocoaPods/vendored_frameworks will bundle it.
add_library(arabic_text_justification STATIC
        ../../src/harfbuzz_wrapper.cpp
)

target_include_directories(arabic_text_justification PRIVATE
        ${HB_ROOT}/src
        ${FT_ROOT}/include
)

target_link_libraries(arabic_text_justification PRIVATE
        harfbuzz
        freetype
)

# Combine all static libs into one archive so the final .a is self-contained.
set_target_properties(arabic_text_justification PROPERTIES
        OUTPUT_NAME arabic_text_justification
)
