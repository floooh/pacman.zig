const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const builtin = @import("builtin");

const emcc_path = "/Users/floh/projects/fips-sdks/emsdk/upstream/emscripten/emcc";

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    if (target.getCpu().arch == .wasm32) {
        buildWasm(b, target, mode);
    }
    else {
        buildNative(b, target, mode);
    }
}

fn buildNative(b: *Builder, target: CrossTarget, mode: Mode) void {
    const exe = b.addExecutable("pacman", null);
    const cross_compiling_to_darwin = target.isDarwin() and (target.getOsTag() != builtin.os.tag);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addObject(objGame(b, target, mode, cross_compiling_to_darwin));
    exe.linkLibrary(libSokol(b, target, mode, cross_compiling_to_darwin, ""));
    exe.install();

    if (target.getOsTag() == .ios) {
        const install_path = std.fmt.allocPrint(b.allocator, "{s}/bin/pacman", .{b.install_path}) catch unreachable;
        defer b.allocator.free(install_path);
        b.installFile(install_path, "bin/Pacman.app/pacman");
        b.installFile("src/ios/Info.plist", "bin/Pacman.app/Info.plist");
    }
    b.step("run", "Run pacman").dependOn(&exe.run().step);
}

fn buildWasm(b: *Builder, target: CrossTarget, mode: Mode) void {
    // build sokol into a library
    const include_path = std.fmt.allocPrint(b.allocator, "{s}/include", .{ b.sysroot }) catch unreachable;
    defer b.allocator.free(include_path);
    const libpath_option = std.fmt.allocPrint(b.allocator, "-L{s}/lib/wasm32-emscripten", .{ b.sysroot }) catch unreachable;
    defer b.allocator.free(libpath_option);
//    const sokol = libSokol(b, target, mode, false, "");
//    sokol.defineCMacro("__EMSCRIPTEN__", null);
//    sokol.addIncludeDir(include_path);
//    sokol.install();
    
    // build game code into an object
    const game = libGame(b, target, mode, false);
    game.install();
    
    const emcc = b.addSystemCommand(&.{
        emcc_path,
        "src/emscripten/entry.c",
        "-ozig-out/bin/pacman.html",
        "--shell-file", "src/emscripten/shell.html",
        libpath_option,
        "-Lzig-out/lib/",
        "-lgame",
        "-lsokol",
        "-sUSE_WEBGL2",
//        "-sERROR_ON_UNDEFINED_SYMBOLS=0",
    });
//    emcc.step.dependOn(&sokol.step);
    emcc.step.dependOn(&game.step);
    
    const exe = b.addExecutable("dummy", null);
    exe.step.dependOn(&emcc.step);
    exe.install();
}

// build the game code into a separate object, makes it easier to handle the separate Emscripten link step for WASM
fn objGame(b: *Builder, target: CrossTarget, mode: Mode, cross_compiling_to_darwin: bool) *LibExeObjStep {
    const obj = b.addObject("game", "src/pacman.zig");
    obj.setTarget(target);
    obj.setBuildMode(mode);
    obj.addPackagePath("sokol", "src/sokol/sokol.zig");
    if (cross_compiling_to_darwin) {
        addDarwinCrossCompilePaths(b, obj);
    }
    return obj;
}

// build the game code into a separate object, makes it easier to handle the separate Emscripten link step for WASM
fn libGame(b: *Builder, target: CrossTarget, mode: Mode, cross_compiling_to_darwin: bool) *LibExeObjStep {
    const lib = b.addStaticLibrary("game", "src/pacman.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.addPackagePath("sokol", "src/sokol/sokol.zig");
    if (cross_compiling_to_darwin) {
        addDarwinCrossCompilePaths(b, lib);
    }
    return lib;
}

fn libSokol(b: *Builder, target: CrossTarget, mode: Mode, cross_compiling_to_darwin: bool, comptime prefix_path: []const u8) *LibExeObjStep {
    const lib = b.addStaticLibrary("sokol", null);
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.linkLibC();
    const sokol_path = prefix_path ++ "src/sokol/sokol.c";
    if (lib.target.isDarwin()) {
        lib.addCSourceFile(sokol_path, &.{ "-ObjC" });
        lib.linkFramework("MetalKit");
        lib.linkFramework("Metal");
        lib.linkFramework("AudioToolbox");
        if (target.getOsTag() == .ios) {
            lib.linkFramework("UIKit");
            lib.linkFramework("AVFoundation");
            lib.linkFramework("Foundation");
        }
        else {
            lib.linkFramework("Cocoa");
            lib.linkFramework("QuartzCore");
        }
    }
    else {
        lib.addCSourceFile(sokol_path, &.{});
        if (lib.target.isLinux()) {
            lib.linkSystemLibrary("X11");
            lib.linkSystemLibrary("Xi");
            lib.linkSystemLibrary("Xcursor");
            lib.linkSystemLibrary("GL");
            lib.linkSystemLibrary("asound");
        }
        else if (lib.target.isWindows()) {
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
    step.addLibPath("/usr/lib");
    step.addSystemIncludeDir("/usr/include");
    step.addFrameworkDir("/System/Library/Frameworks");
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
