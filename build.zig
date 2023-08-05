const std = @import("std");
const fs = std.fs;
const Build = std.Build;
const CompileStep = std.build.Step.Compile;
const Dependency = std.build.Dependency;
const CrossTarget = std.zig.CrossTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const builtin = @import("builtin");

// NOTE: the sokol dependency consists of two parts:
//
// - a regular Zig module with the bindings interface
// - a static link library with the compiled C code
//
// I didn't find a solution to treat the C library dependency
// as an 'install artifact' (there doesn't seem to be a way to
// communicate a custom sysroot to the dependency build process).
//
// That's why the C library is configured by directly calling a function
// 'buildLibSokol()' in the sokol-dependency build.zig, which is
// imported via @import("sokol").
//
const sokol = @import("sokol");

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{});
    if (target.getCpu().arch != .wasm32) {
        buildNative(b, target, optimize, dep_sokol) catch unreachable;
    } else {
        buildWasm(b, target, optimize, dep_sokol) catch |err| {
            std.log.err("{}", .{err});
        };
    }
}

// this is the regular build for all native platforms
fn buildNative(b: *Build, target: CrossTarget, optimize: OptimizeMode, dep_sokol: *Dependency) !void {
    const exe = b.addExecutable(.{
        .name = "pacman",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    exe.addModule("sokol", dep_sokol.module("sokol"));
    const lib_sokol = try sokol.buildLibSokol(b, .{
        .build_root = dep_sokol.builder.build_root.path,
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lib_sokol);
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run pacman").dependOn(&run.step);

    // for iOS generate a valid app bundle directory structure
    if (target.getOsTag() == .ios) {
        const install_path = try fs.path.join(b.allocator, &.{ b.install_path, "bin", "pacman" });
        defer b.allocator.free(install_path);
        b.installFile(install_path, "bin/Pacman.app/pacman");
        b.installFile("src/ios/Info.plist", "bin/Pacman.app/Info.plist");
    }
}

// building for WASM/HTML5 requires a couple of hacks and workarounds:
//
//  - emcc must be used as linker instead of the zig linker to implement
//    the additional "Emscripten magic" (e.g. generating the .html and .js
//    file, setting up the web API shims, etc...)
//  - the Sokol C headers must be compiled as target wasm32-emscripten, otherwise
//    the EMSCRIPTEN_KEEPALIVE and EM_JS macro magic doesn't work
//  - the Zig code must be compiled with target wasm32-freestanding
//    (see https://github.com/ziglang/zig/issues/10836)
//  - an additional header search path into Emscripten's sysroot
//    must be set so that the C code compiled with Zig finds the Emscripten
//    sysroot headers
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
    if (target.os_tag != .freestanding) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-freestanding --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot", .{});
        return error.Wasm32FreestandingExpected;
    }

    const libsokol = try sokol.buildLibSokol(b, .{
        .build_root = dep_sokol.builder.build_root.path,
        .sysroot = b.sysroot,
        .target = target,
        .optimize = optimize,
    });

    // the game code can be compiled either with wasm32-freestanding or wasm32-emscripten
    const libgame = b.addStaticLibrary(.{
        .name = "game",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    libgame.addModule("sokol", dep_sokol.module("sokol"));
    const install_libgame = b.addInstallArtifact(libgame, .{});
    const install_libsokol = b.addInstallArtifact(libsokol, .{});

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
