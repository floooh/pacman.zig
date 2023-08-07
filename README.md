# pacman.zig

[![build](https://github.com/floooh/pacman.zig/actions/workflows/main.yml/badge.svg)](https://github.com/floooh/pacman.zig/actions/workflows/main.yml)

Like https://github.com/floooh/pacman.c, but in Zig.

Zig bindings for the sokol headers are here: https://github.com/floooh/sokol-zig

[WASM version](https://floooh.github.io/pacman.zig/pacman.html)

## Build and Run

Requires Zig version 0.11.0

Zig installation: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

```bash
git clone https://github.com/floooh/pacman.zig
cd pacman.zig
zig build run
```

On Windows, rendering is done through D3D11, on Linux through OpenGL and
on macOS through Metal.

On Linux, you need to install the usual dev-packages for GL-, X11- and ALSA-development.

## Experimental web support

Building the project to run in web browsers requires the Emscripten SDK to provide
a sysroot and linker:

```bash
git clone https://github.com/floooh/pacman.zig
cd pacman.zig

# install emsdk into a subdirectory
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
cd ..

# build for wasm32-freestanding
zig build -Doptimize=ReleaseSmall -Dtarget=wasm32-freestanding --sysroot emsdk/upstream/emscripten/cache/sysroot
```

The resulting .html, .js and .wasm files are under ```zig-out/web```.

...to build and start the result in a browser, add a 'run' argument to 'zig build', this
uses the Emscripten SDK ```emrun``` tool to start a local webserver and the browser.
Note that you need to hit ```Ctrl-C``` to exit after closing the browser:

```bash
zig build run -Doptimize=ReleaseSmall -Dtarget=wasm32-freestanding --sysroot emsdk/upstream/emscripten/cache/sysroot
```

Note that the Emscripten build currently requires a couple of hacks and workarounds in
the build process, details are in the build.zig file.
