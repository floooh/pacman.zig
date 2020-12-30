const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;
const builtin = @import("std").builtin;

// build sokol into its own static link library
fn buildSokol(b: *Builder) *LibExeObjStep {
    const l = b.addStaticLibrary("sokol", null);
    l.addCSourceFile("src/sokol/sokol.c", &[_][]const u8{});
    l.setBuildMode(b.standardReleaseOptions());
    l.linkSystemLibrary("c");
    if (builtin.os.tag == .linux) {
        l.linkSystemLibrary("X11");
        l.linkSystemLibrary("Xi");
        l.linkSystemLibrary("Xcursor");
        l.linkSystemLibrary("GL");
        l.linkSystemLibrary("asound");
    }
    return l;
}

pub fn build(b: *Builder) void {
    const e = b.addExecutable("pacman", "src/pacman.zig");
    e.linkLibrary(buildSokol(b));
    e.setBuildMode(b.standardReleaseOptions());
    e.addPackagePath("sokol", "src/sokol/sokol.zig");
    e.install();
    b.step("run", "Run pacman").dependOn(&e.run().step);
}
