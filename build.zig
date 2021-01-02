const bld = @import("std").build;
const mem = @import("std").mem;
const zig = @import("std").zig;

// macOS helper function to add SDK search paths 
fn macosAddSdkDirs(b: *bld.Builder, step: *bld.LibExeObjStep) !void {
    const sdk_dir = try zig.system.getSDKPath(b.allocator);
    const framework_dir = try mem.concat(b.allocator, u8, &[_][]const u8 { sdk_dir, "/System/Library/Frameworks" });
    const usrinclude_dir = try mem.concat(b.allocator, u8, &[_][]const u8 { sdk_dir, "/usr/include"});
    step.addFrameworkDir(framework_dir);
    step.addIncludeDir(usrinclude_dir);
}

fn addSokol(b: *bld.Builder, exe: *bld.LibExeObjStep) !void {
    if (exe.target.isDarwin()) {
        try macosAddSdkDirs(b, exe);
        exe.addCSourceFile("src/sokol/sokol.c", &[_][]const u8 { "-ObjC" });
        exe.linkFramework("MetalKit");
        exe.linkFramework("Metal");
        exe.linkFramework("Cocoa");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("AudioToolbox");
    }
    else {
        exe.addCSourceFile("src/sokol/sokol.c", &[_][]const u8{});
        exe.linkSystemLibrary("c");
        if (exe.target.isLinux()) {
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xcursor");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("asound");
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
