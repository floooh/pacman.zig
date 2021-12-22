# pacman.zig
Like https://github.com/floooh/pacman.c, but in Zig.

Zig bindings for the sokol headers are here: https://github.com/floooh/sokol-zig

## Build and Run

Requires Zig version 0.9.0.

Zig installation: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

```bash
> git clone https://github.com/floooh/pacman.zig
> cd pacman.zig
> zig build run
```

On Windows, rendering is done through D3D11, on Linux through OpenGL and
on macOS through Metal.

On Linux, you need to install the usual dev-packages for GL-, X11- and ALSA-development.

## Experimental iOS support

NOTE: this is mostly a "it technically works" demo, the game can't be played with 
touch inputs yet, only tapping is detected to get from the intro screen into
the game loop.

Since building for iOS is a cross-compilation-scenario, Xcode must be installed to
provide the iOS platform SDKs.

For the iOS simulator:

```bash
> git clone https://github.com/floooh/pacman.zig
> cd pacman.zig
> zig build --sysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -Dtarget=aarch64-ios-simulator
# start the simulator...
> open -a Simulator.app
# wait until the simulator has booted up, then install the app with:
> xcrun simctl install booted zig-out/bin/Pacman.app
# run the game with:
> xcrun simctl launch booted Pacman.zig 
```

Building for an actual device works like this, but installing and running hasn't been tested yet:

```bash
> git clone https://github.com/floooh/pacman.zig
> cd pacman.zig
> zig build --sysroot $(xcrun --sdk iphoneos --show-sdk-path) -Dtarget=aarch64-ios
```

