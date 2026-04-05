cmake_minimum_required(VERSION 3.10)
project(arabic_text_justification)

set(HB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/harfbuzz)
set(FT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/freetype)

# Build FreeType from source (disable unnecessary modules)
set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
add_subdirectory(${FT_ROOT} freetype_build)

# Build HarfBuzz from source with FreeType support
set(HB_HAVE_FREETYPE ON CACHE BOOL "" FORCE)
add_subdirectory(${HB_ROOT} harfbuzz_build)

# Build our wrapper as shared library
add_library(arabic_text_justification SHARED
        ../src/harfbuzz_wrapper.cpp
)

target_include_directories(arabic_text_justification PRIVATE
        ${HB_ROOT}/src
        ${FT_ROOT}/include
)

target_link_libraries(arabic_text_justification
        harfbuzz
        freetype
        android
        log
)
