const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;

export fn init() void {
    sg.setup(.{ .context = sgapp.context() });
}

export fn frame() void {
    sg.beginDefaultPass(.{}, sapp.width(), sapp.height());
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 640,
        .height = 480,
        .window_title = "pacman.zig"
    });
}
