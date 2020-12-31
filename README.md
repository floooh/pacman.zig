# pacman.zig
Like https://github.com/floooh/pacman.c, but in Zig

Zig bindings for the sokol headers are here: https://github.com/floooh/sokol-zig

## Build and Run

Zig installation: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

On **macOS** only, a 'system linker hack' is currently needed which requires setting
an environment variable in the shell session where 'zig build' will run:

```
# macOS only:
> export ZIG_SYSTEM_LINKER_HACK=1
```

From here on it's the same procedure on macOS, Windows and Linux:
```
> git clone https://github.com/floooh/pacman.zig
> cd pacman.zig
> zig build run
```
Tested with zig version 0.7.1+

On Windows, rendering is done through D3D11, on Linux through OpenGL and
on macOS through Metal.

On Linux, you need to install the usual packages for GL-, X11- and ALSA-development.
