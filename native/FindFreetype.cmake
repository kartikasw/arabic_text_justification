# Custom FindFreetype that points to the subdirectory-built freetype target.
# Placed on CMAKE_MODULE_PATH so HarfBuzz's include(FindFreetype) picks it up
# instead of the system module.
set(FREETYPE_FOUND TRUE)
set(FREETYPE_INCLUDE_DIRS "${FT_ROOT}/include")
set(FREETYPE_LIBRARIES freetype)
