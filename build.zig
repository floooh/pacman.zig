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
}

fn addSokol(exe: *bld.LibExeObjStep) void {
    exe.linkLibC();
    if (exe.target.isDarwin()) {
        if (!@import("builtin").target.isDarwin()) {
            exe.addSystemIncludeDir("/usr/include");
            exe.addLibPath("/usr/lib");
            exe.addFrameworkDir("/System/Library/Frameworks");
        }
        exe.addCSourceFile("src/sokol/sokol.c", &.{ "-ObjC" });
        exe.linkFramework("MetalKit");
        exe.linkFramework("Metal");
        exe.linkFramework("Cocoa");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("AudioToolbox");
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
