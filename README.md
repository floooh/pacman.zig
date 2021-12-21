# pacman.zig
Like https://github.com/floooh/pacman.c, but in Zig.

Zig bindings for the sokol headers are here: https://github.com/floooh/sokol-zig

## Build and Run

Requires Zig version 0.9.0.

Zig installation: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

```
> git clone https://github.com/floooh/pacman.zig
> cd pacman.zig
> zig build run
```

On Windows, rendering is done through D3D11, on Linux through OpenGL and
on macOS through Metal.

On Linux, you need to install the usual dev-packages for GL-, X11- and ALSA-development.
