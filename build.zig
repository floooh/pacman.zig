const Builder = @import("std").build.Builder;
const builtin = @import("std").builtin;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const e = b.addExecutable("pacman", "src/pacman.zig");
    if (builtin.os.tag == .linux) {
        e.linkSystemLibrary("X11");
        e.linkSystemLibrary("Xi");
        e.linkSystemLibrary("Xcursor");
        e.linkSystemLibrary("GL");
    }
    e.setBuildMode(mode);
    e.addPackagePath("sokol", "src/sokol/sokol.zig");
    e.addCSourceFile("src/sokol/sokol.c", &[_][]const u8{});
    e.linkSystemLibrary("c");
    e.install();
    b.step("run", "Run pacman").dependOn(&e.run().step);
}
