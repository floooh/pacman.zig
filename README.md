# pacman.zig
Like https://github.com/floooh/pacman.c, but in Zig (WIP)

## Build and Run

>NOTE: Currently only Linux and Windows is supported, Mac might take while

```
git clone https://github.com/floooh/pacman.zig
cd pacman.zig
zig build run
```
On Windows, rendering is done through D3D11, on Linux through OpenGL.

On Linux, you need to install the usual packages for GL-, X11- and ALSA-development.
