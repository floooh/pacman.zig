#define SOKOL_IMPL
#define SOKOL_ZIG_BINDINGS
#define SOKOL_NO_ENTRY
#if defined(_WIN32)
    #define SOKOL_WIN32_FORCE_MAIN
    #define SOKOL_D3D11
    #define SOKOL_LOG(msg) OutputDebugStringA(msg)
#elif defined(__APPLE__)
    #define SOKOL_METAL
#elif defined(__EMSCRIPTEN__)
    #define SOKOL_GLES2
#else
    #define SOKOL_GLCORE33
#endif
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_audio.h"
