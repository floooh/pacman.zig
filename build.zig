const std = @import("std");
const bld = @import("std").build;

pub fn build(b: *bld.Builder) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("pacman", "src/pacman.zig");
    exe.setTarget(target);
    addSokol(exe);
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    exe.install();
    b.step("run", "Run pacman").dependOn(&exe.run().step);
    const install_path = std.fmt.allocPrint(b.allocator, "{s}/bin/pacman", .{b.install_path}) catch unreachable;
    std.debug.print("install_path: {s}\n", .{ install_path });
    defer b.allocator.free(install_path);
    b.installFile(install_path, "bin/Pacman.app/pacman");
    b.installFile("Info.plist", "bin/Pacman.app/Info.plist");
}

fn addSokol(exe: *bld.LibExeObjStep) void {
    exe.linkLibC();
    if (exe.target.isDarwin()) {
//        if (!@import("builtin").target.isDarwin()) {
            // NOTE: this is for cross-compilation support
            //const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS15.2.sdk";
            const sdk_path = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator15.2.sdk";
            exe.addSystemIncludeDir(sdk_path ++ "/usr/include");
            exe.addLibPath(sdk_path ++ "/usr/lib");
            exe.addFrameworkDir(sdk_path ++ "/System/Library/Frameworks");
//        }
        exe.addCSourceFile("src/sokol/sokol.c", &.{ "-ObjC" });
        exe.linkFramework("MetalKit");
        exe.linkFramework("Metal");
        exe.linkFramework("UIKit");
        exe.linkFramework("AudioToolbox");
        exe.linkFramework("CoreFoundation");
        exe.linkFramework("Foundation");
        exe.linkFramework("AVFoundation");
        exe.linkFramework("FileProvider");
        exe.linkSystemLibrary("System.B");
        exe.linkSystemLibrary("objc.A");

    }
    else {
        exe.addCSourceFile("src/sokol/sokol.c", &.{});
        if (exe.target.isLinux()) {
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xcursor");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("asound");
        }
        else if (exe.target.isWindows()) {
            exe.linkSystemLibrary("kernel32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("d3d11");
            exe.linkSystemLibrary("dxgi");
        }
    }
}
