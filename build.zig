const bld = @import("std").build;

fn addSokol(b: *bld.Builder, exe: *bld.LibExeObjStep) !void {
    exe.linkLibC();
    if (exe.target.isDarwin()) {
        b.env_map.put("ZIG_SYSTEM_LINKER_HACK", "1") catch unreachable;
        exe.addCSourceFile("src/sokol/sokol.c", &[_][]const u8 { "-ObjC" });
        exe.linkFramework("MetalKit");
        exe.linkFramework("Metal");
        exe.linkFramework("Cocoa");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("AudioToolbox");
    }
    else {
        exe.addCSourceFile("src/sokol/sokol.c", &[_][]const u8{});
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
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("d3d11");
            exe.linkSystemLibrary("dxguid");
            exe.linkSystemLibrary("dxgi");
        }
    }
}

pub fn build(b: *bld.Builder) void {
    const exe = b.addExecutable("pacman", "src/pacman.zig");
    addSokol(b, exe) catch unreachable;
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    exe.install();
    b.step("run", "Run pacman").dependOn(&exe.run().step);
}
