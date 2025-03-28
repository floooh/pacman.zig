const std = @import("std");
const Build = std.Build;
const sokol = @import("sokol");

const Options = struct {
    mod: *Build.Module,
    dep_sokol: *Build.Dependency,
};

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const mod_pacman = b.createModule(.{
        .root_source_file = b.path("src/pacman.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
        },
    });

    // special case handling for native vs web build
    const opts = Options{ .mod = mod_pacman, .dep_sokol = dep_sokol };
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, opts);
    } else {
        try buildNative(b, opts);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, opts: Options) !void {
    const exe = b.addExecutable(.{
        .name = "pacman",
        .root_module = opts.mod,
    });
    const shd = try buildShader(b, opts.dep_sokol);
    exe.step.dependOn(&shd.step);
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run pacman").dependOn(&run.step);
}

// for web builds, the Zig code needs to be built into a library and linked with the Emscripten linker
fn buildWeb(b: *Build, opts: Options) !void {
    const lib = b.addStaticLibrary(.{
        .name = "pacman",
        .root_module = opts.mod,
    });
    const shd = try buildShader(b, opts.dep_sokol);
    lib.step.dependOn(&shd.step);

    // create a build step which invokes the Emscripten linker
    const emsdk = opts.dep_sokol.builder.dependency("emsdk", .{});
    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = lib,
        .target = opts.mod.resolved_target.?,
        .optimize = opts.mod.optimize.?,
        .emsdk = emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = opts.dep_sokol.path("src/sokol/web/shell.html"),
    });
    // attach Emscripten linker output to default install step
    b.getInstallStep().dependOn(&link_step.step);
    // ...and a special run step to start the web build output via 'emrun'
    const run = sokol.emRunStep(b, .{ .name = "pacman", .emsdk = emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run pacman").dependOn(&run.step);
}

// compile shader via sokol-shdc
fn buildShader(b: *Build, dep_sokol: *Build.Dependency) !*Build.Step.Run {
    return try sokol.shdc.compile(b, .{
        .dep_shdc = dep_sokol.builder.dependency("shdc", .{}),
        .input = b.path("src/shader.glsl"),
        .output = b.path("src/shader.zig"),
        .slang = .{
            .glsl410 = true,
            .glsl300es = true,
            .hlsl4 = true,
            .metal_macos = true,
            .wgsl = true,
        },
    });
}
