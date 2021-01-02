const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;
const builtin = @import("std").builtin;
const mem = @import("std").mem;

// macOS helper function to add SDK search paths 
fn macosAddSdkDirs(b: *Builder, step: *LibExeObjStep) !void {
    var sdk_dir = try b.exec(&[_][]const u8 { "xcrun", "--show-sdk-path" });
    const newline_index = mem.lastIndexOf(u8, sdk_dir, "\n");
    if (newline_index) |idx| {
        sdk_dir = sdk_dir[0..idx];
    }
    const framework_dir = try mem.concat(b.allocator, u8, &[_][]const u8 { sdk_dir, "/System/Library/Frameworks" });
    const usrinclude_dir = try mem.concat(b.allocator, u8, &[_][]const u8 { sdk_dir, "/usr/include"});
    step.addFrameworkDir(framework_dir);
    step.addIncludeDir(usrinclude_dir);
}

fn addSokol(b: *Builder, exe: *LibExeObjStep) !void {
    if (builtin.os.tag == .macos) {
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
        if (builtin.os.tag == .linux) {
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xcursor");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("asound");
        }
    }
}

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("pacman", "src/pacman.zig");
    addSokol(b, exe) catch unreachable;
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    exe.install();
    b.step("run", "Run pacman").dependOn(&exe.run().step);
}
