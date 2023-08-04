const std = @import("std");
const fs = std.fs;
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    if (target.getCpu().arch != .wasm32) {
        buildNative(b, target, optimize) catch unreachable;
    } else {
        buildWasm(b, target, optimize) catch |err| {
            std.log.err("{}", .{err});
        };
    }
}

// this is the regular build for all native platforms
fn buildNative(b: *Builder, target: CrossTarget, optimize: Mode) !void {
    const exe = b.addExecutable(.{
        .name = "pacman",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    const cross_compiling_to_darwin = target.isDarwin() and (target.getOsTag() != builtin.os.tag);
    exe.addAnonymousModule("sokol", .{ .source_file = .{ .path = "src/sokol/sokol.zig" } });
    exe.linkLibrary(libSokol(b, target, optimize, cross_compiling_to_darwin, ""));
    if (cross_compiling_to_darwin) {
        addDarwinCrossCompilePaths(b, exe);
    }
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
//  - an additional header search path into Emscripten's sysroot
//    must be set so that the C code compiled with Zig finds the Emscripten
//    sysroot headers
//  - the Zig code must *not* be compiled with wasm32-emscripten, because parts
//    of the Zig stdlib doesn't compile, so instead use wasm32-freestanding
//  - the game code in pacman.zig is compiled into a library, and a
//    C file (src/emscripten/entry.c) is used as entry point, which then
//    calls an exported entry function "emsc_main()" in pacman.zig instead
//    of the regular zig main function.
//
fn buildWasm(b: *Builder, target: CrossTarget, optimize: Mode) !void {
    if (b.sysroot == null) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-emscripten --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot", .{});
        return error.SysRootExpected;
    }

    // derive the emcc and emrun paths from the provided sysroot:
    const emcc_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emcc" });
    defer b.allocator.free(emcc_path);
    const emrun_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emrun" });
    defer b.allocator.free(emrun_path);

    // for some reason, the sysroot/include path must be provided separately
    const include_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
    defer b.allocator.free(include_path);

    // sokol must be built with wasm32-emscripten
    var wasm32_emscripten_target = target;
    wasm32_emscripten_target.os_tag = .emscripten;
    const libsokol = libSokol(b, wasm32_emscripten_target, optimize, false, "");
    libsokol.defineCMacro("__EMSCRIPTEN__", "1");
    libsokol.addIncludePath(.{ .path = include_path });
    const install_libsokol = b.addInstallArtifact(libsokol, .{});

    // the game code must be build as library with wasm32-freestanding
    var wasm32_freestanding_target = target;
    wasm32_freestanding_target.os_tag = .freestanding;
    const libgame = b.addStaticLibrary(.{
        .name = "game",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    libgame.addAnonymousModule("sokol", .{ .source_file = .{ .path = "src/sokol/sokol.zig" } });
    const install_libgame = b.addInstallArtifact(libgame, .{});

    // call the emcc linker step as a 'system command' zig build step which
    // depends on the libsokol and libgame build steps
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
        "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main']",
    });
    emcc.step.dependOn(&install_libsokol.step);
    emcc.step.dependOn(&install_libgame.step);

    // get the emcc step to run on 'zig build'
    b.getInstallStep().dependOn(&emcc.step);

    // a seperate run step using emrun
    const emrun = b.addSystemCommand(&.{ emrun_path, "zig-out/web/pacman.html" });
    emrun.step.dependOn(&emcc.step);
    b.step("run", "Run pacman").dependOn(&emrun.step);
}

fn libSokol(b: *Builder, target: CrossTarget, optimize: Mode, cross_compiling_to_darwin: bool, comptime prefix_path: []const u8) *LibExeObjStep {
    const lib = b.addStaticLibrary(.{
        .name = "sokol",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    const sokol_path = prefix_path ++ "src/sokol/sokol.c";
    if (lib.target.isDarwin()) {
        lib.addCSourceFile(.{
            .file = .{ .path = sokol_path },
            .flags = &.{"-ObjC"},
        });
        lib.linkFramework("MetalKit");
        lib.linkFramework("Metal");
        lib.linkFramework("AudioToolbox");
        if (target.getOsTag() == .ios) {
            lib.linkFramework("UIKit");
            lib.linkFramework("AVFoundation");
            lib.linkFramework("Foundation");
        } else {
            lib.linkFramework("Cocoa");
            lib.linkFramework("QuartzCore");
        }
    } else {
        lib.addCSourceFile(.{
            .file = .{ .path = sokol_path },
            .flags = &.{},
        });
        if (lib.target.isLinux()) {
            lib.linkSystemLibrary("X11");
            lib.linkSystemLibrary("Xi");
            lib.linkSystemLibrary("Xcursor");
            lib.linkSystemLibrary("GL");
            lib.linkSystemLibrary("asound");
        } else if (lib.target.isWindows()) {
            lib.linkSystemLibrary("kernel32");
            lib.linkSystemLibrary("user32");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("ole32");
            lib.linkSystemLibrary("d3d11");
            lib.linkSystemLibrary("dxgi");
        }
    }
    // setup cross-compilation search paths
    if (cross_compiling_to_darwin) {
        addDarwinCrossCompilePaths(b, lib);
    }
    return lib;
}

fn addDarwinCrossCompilePaths(b: *Builder, step: *LibExeObjStep) void {
    checkDarwinSysRoot(b);
    step.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
    step.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    step.addFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });
}

fn checkDarwinSysRoot(b: *Builder) void {
    if (b.sysroot == null) {
        std.log.warn("===================================================================================", .{});
        std.log.warn("You haven't set the path to Apple SDK which may lead to build errors.", .{});
        std.log.warn("Hint: you can the path to Apple SDK with --sysroot <path> flag like so:", .{});
        std.log.warn("  zig build --sysroot $(xcrun --sdk iphoneos --show-sdk-path) -Dtarget=aarch64-ios", .{});
        std.log.warn("or:", .{});
        std.log.warn("  zig build --sysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -Dtarget=aarch64-ios-simulator", .{});
        std.log.warn("===================================================================================", .{});
    }
}
