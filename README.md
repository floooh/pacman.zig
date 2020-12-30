# pacman.zig
Like https://github.com/floooh/pacman.c, but in Zig

Zig bindings for the sokol headers are here: https://github.com/floooh/sokol-zig

## Build and Run

Zig installation: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

>NOTE: Currently only Linux and Windows is supported, Mac might take while

```
git clone https://github.com/floooh/pacman.zig
cd pacman.zig
zig build run
```
Tested with zig version 0.7.1+

On Windows, rendering is done through D3D11, on Linux through OpenGL.

On Linux, you need to install the usual packages for GL-, X11- and ALSA-development.
