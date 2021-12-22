const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("pacman", "src/pacman.zig");
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const cross_compiling = (target.os_tag != null) or !builtin.target.isDarwin();

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibrary(buildSokol(b, target, mode, cross_compiling, ""));
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    if (cross_compiling) {
        exe.addLibPath("/usr/lib");
        exe.addFrameworkDir("/System/Library/Frameworks");
    }
    exe.install();

    b.step("run", "Run pacman").dependOn(&exe.run().step);
    
    if (target.getOsTag() == .ios) {
        const install_path = std.fmt.allocPrint(b.allocator, "{s}/bin/pacman", .{b.install_path}) catch unreachable;
        defer b.allocator.free(install_path);
        b.installFile(install_path, "bin/Pacman.app/pacman");
        b.installFile("src/ios/Info.plist", "bin/Pacman.app/Info.plist");
    }
}

fn buildSokol(b: *Builder, target: CrossTarget, mode: Mode, cross_compiling: bool, comptime prefix_path: []const u8) *LibExeObjStep {
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
    if (cross_compiling) {
        if (b.sysroot == null) {
            std.log.warn("===================================================================================", .{});
            std.log.warn("You haven't set the path to Apple SDK which may lead to build errors.", .{});
            std.log.warn("Hint: you can the path to Apple SDK with --sysroot <path> flag like so:", .{});
            std.log.warn("  zig build --sysroot $(xcrun --sdk iphoneos --show-sdk-path) -Dtarget=aarch64-ios", .{});
            std.log.warn("or:", .{});
            std.log.warn("  zig build --sysroot $(xcrun --sdk iphonesimulator --show-sdk-path) -Dtarget=aarch64-ios-simulator", .{});
            std.log.warn("===================================================================================", .{});
        }
        lib.addFrameworkDir("/System/Library/Frameworks");
        lib.addSystemIncludeDir("/usr/include");
    }
    return lib;
}
