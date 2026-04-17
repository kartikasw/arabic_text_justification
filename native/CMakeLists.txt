cmake_minimum_required(VERSION 3.10)
project(arabic_text_justification)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

set(HB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/harfbuzz)
set(FT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/freetype)

set(FT_DISABLE_BZIP2 ON CACHE BOOL "" FORCE)
set(FT_DISABLE_PNG ON CACHE BOOL "" FORCE)
set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "" FORCE)
set(FT_DISABLE_BROTLI ON CACHE BOOL "" FORCE)
set(FT_DISABLE_ZLIB ON CACHE BOOL "" FORCE)
add_subdirectory(${FT_ROOT} freetype_build)

set(HB_HAVE_FREETYPE ON CACHE BOOL "" FORCE)
set(HB_BUILD_TESTS OFF CACHE BOOL "" FORCE)
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}")
add_subdirectory(${HB_ROOT} harfbuzz_build)
target_compile_definitions(harfbuzz PRIVATE HB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR)
target_compile_definitions(harfbuzz-subset PRIVATE HB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR)

add_library(arabic_text_justification SHARED
        ../src/harfbuzz_wrapper.cpp
)

target_include_directories(arabic_text_justification PRIVATE
        ${HB_ROOT}/src
        ${FT_ROOT}/include
)

target_link_libraries(arabic_text_justification PRIVATE
        harfbuzz
        freetype
        android
        log
)
