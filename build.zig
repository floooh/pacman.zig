const std = @import("std");
const fs = std.fs;
const Build = std.Build;
const CompileStep = std.build.Step.Compile;
const Dependency = std.build.Dependency;
const CrossTarget = std.zig.CrossTarget;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *Build) !void {

    // hack: patch the sysroot into an absolute path, otherwise the relative sysroot path
    // would break down in the dependencies
    if (b.sysroot) |sysroot| {
        b.sysroot = try fs.cwd().realpathAlloc(b.allocator, sysroot);
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // get the sokol bindings package dependency, important: need to communicate the
    // CrossTarget and OptimizeMode here, otherwise cross-compilation won't work
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    // special case handling for native vs web build
    if (target.getCpu().arch != .wasm32) {
        try buildNative(b, target, optimize, dep_sokol);
    } else {
        try buildWasm(b, target, optimize, dep_sokol);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, target: CrossTarget, optimize: OptimizeMode, dep_sokol: *Dependency) !void {
    const exe = b.addExecutable(.{
        .name = "pacman",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    exe.addModule("sokol", dep_sokol.module("sokol"));
    exe.linkLibrary(dep_sokol.artifact("sokol"));
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run pacman").dependOn(&run.step);
}

// building for WASM/HTML5 requires a couple of hacks and workarounds:
//
//  - emcc must be used as linker instead of the zig linker to implement
//    the additional "Emscripten magic" (e.g. generating the .html and .js
//    file, setting up the web API shims, etc...)
//  - an additional header search path into Emscripten's sysroot
//    must be set so that the C code compiled with Zig finds the Emscripten
//    sysroot headers (this is taken care of now in the sokol-zig package build.zig)
//  - the Sokol C headers must be compiled as target wasm32-emscripten, otherwise
//    the EMSCRIPTEN_KEEPALIVE and EM_JS macro magic doesn't work
//    (this is also taken care of now in the sokol-zig package)
//  - the Zig code must be compiled with target wasm32-freestanding
//    (see https://github.com/ziglang/zig/issues/10836)
//  - the game code in pacman.zig is compiled into a library, and a
//    C file (src/emscripten/entry.c) is used as entry point, which then
//    calls an exported entry function "emsc_main()" in pacman.zig instead
//    of the regular zig main function.
//
fn buildWasm(b: *Build, target: CrossTarget, optimize: OptimizeMode, dep_sokol: *Dependency) !void {
    if (b.sysroot == null) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-freestanding --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot", .{});
        return error.SysRootExpected;
    }
    // see: https://github.com/ziglang/zig/issues/10836#issuecomment-1666488896
    if (target.os_tag != .freestanding) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-freestanding --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot", .{});
        return error.Wasm32FreestandingExpected;
    }

    const libgame = b.addStaticLibrary(.{
        .name = "game",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    libgame.addModule("sokol", dep_sokol.module("sokol"));
    const install_libgame = b.addInstallArtifact(libgame, .{});
    const install_libsokol = b.addInstallArtifact(dep_sokol.artifact("sokol"), .{});

    // call the emcc linker step as a 'system command' zig build step which
    // depends on the libsokol and libgame build steps
    const emcc_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emcc" });
    defer b.allocator.free(emcc_path);
    try fs.cwd().makePath("zig-out/web");
    const emcc = b.addSystemCommand(&.{
        emcc_path,
        "-Os",
        "--closure",
        "1",
        "src/emscripten/entry.c",
        "-ozig-out/web/pacman.html",
        "--shell-file",
        "src/emscripten/shell.html",
        "-Lzig-out/lib/",
        "-lgame",
        "-lsokol",
        "-sNO_FILESYSTEM=1",
        "-sMALLOC='emmalloc'",
        "-sASSERTIONS=0",
        "-sUSE_WEBGL2=1",
        "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main']",
    });
    emcc.step.dependOn(&install_libsokol.step);
    emcc.step.dependOn(&install_libgame.step);

    // get the emcc step to run on 'zig build'
    b.getInstallStep().dependOn(&emcc.step);

    // a seperate run step using emrun
    const emrun_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emrun" });
    defer b.allocator.free(emrun_path);
    const emrun = b.addSystemCommand(&.{ emrun_path, "zig-out/web/pacman.html" });
    emrun.step.dependOn(&emcc.step);
    b.step("run", "Run pacman").dependOn(&emrun.step);
}
