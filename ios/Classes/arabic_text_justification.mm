// Forwarder + symbol keepalive for the vendored XCFramework.
//
// The XCFramework ships a static library. Without a reference, the linker
// will dead-strip the FFI symbols and DynamicLibrary.process() won't find
// them at runtime. Keep them alive with __attribute__((used)).

#include "arabic_text_justification.h"

__attribute__((used)) static void* _atj_keepalive[] = {
    (void*)shape_line,
    (void*)free_line_result,
    (void*)render_line,
    (void*)free_render_result,
    (void*)get_outline,
    (void*)free_outline_result,
};
