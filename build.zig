const Builder = @import("std").build.Builder;
const LibExeObjStep = @import("std").build.LibExeObjStep;
const builtin = @import("std").builtin;

fn addSokol(b: *Builder, exe: *LibExeObjStep) void {
    if (builtin.os.tag == .macos) {
        //
        // On macOS, can't use Zig's C compiler to build the Sokol headers,
        // because those must be compiled with Objective-C.
        //
        // Building on macOS currently also required setting an env variable
        // to use the system linker instead of Zig's:
        //
        // export ZIG_SYSTEM_LINKER_HACK=1
        //
        // FIXME: use optimization / debug compile options depending on zig build options
        //
        const clangCmd = &[_][]const u8 { "clang", "-x", "objective-c", "-c", "src/sokol/sokol.c", "-Os", "-o", "zig-cache/sokol.o"};
        exe.step.dependOn(&b.addSystemCommand(clangCmd).step);
        exe.addObjectFile("zig-cache/sokol.o");
        exe.linkFramework("MetalKit");
        exe.linkFramework("Metal");
        exe.linkFramework("Cocoa");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("AudioToolbox");
    }
    else {
        // Windows and Linux can use Zig's C compiler and don't need special linker hacks
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
    addSokol(b, exe);
    exe.setBuildMode(b.standardReleaseOptions());
    exe.addPackagePath("sokol", "src/sokol/sokol.zig");
    exe.install();
    b.step("run", "Run pacman").dependOn(&exe.run().step);
}
