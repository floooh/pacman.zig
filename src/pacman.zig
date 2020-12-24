const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;

const NumSprites = 8;
const NumDebugMarkers = 16;
const TileWidth = 8;            // width/height of a background tile in pixels
const TileHeight = 8;
const SpriteWidth = 16;         // width/height of a sprite in pixels
const SpriteHeight = 16;
const DisplayTilesX = 28;       // display width/height in number of tiles
const DisplayTilesY = 36;
const DisplayPixelsX = DisplayTilesX * TileWidth;
const DisplayPixelsY = DisplayTilesY * TileHeight;
const MaxVertices = ((DisplayTilesX*DisplayTilesY) + NumSprites + NumDebugMarkers) * 6;

const State = struct {
    gfx: Gfx = .{},
};
var state: State = .{};

//--- rendering subsystem ------------------------------------------------------
const Gfx = struct {
    const Vertex = packed struct {
        x: f32, y: f32,
        u: f32, v: f32,
        attr: u32,
    };

    pass_action: sg.PassAction = .{},
    offscreen: struct {
        vbuf: sg.Buffer = .{},
        pip: sg.Pipeline = .{},
    } = .{},
    display: struct {
        quad_vbuf: sg.Buffer = .{},
        pip: sg.Pipeline = .{},
    } = .{},

    num_vertices: u32 = 0,
    vertices: [MaxVertices]Vertex = undefined,
};

fn gfxInit() void {
    sg.setup(.{
        .buffer_pool_size = 2,
        .image_pool_size = 3,
        .shader_pool_size = 2,
        .pipeline_pool_size = 2,
        .pass_pool_size = 1,
        .context = sgapp.context()
    });
    gfxCreateResources();
}

fn gfxShutdown() void {
    sg.shutdown();
}

fn gfxCreateResources() void {
    // pass action for clearing background to black
    state.gfx.pass_action.colors[0] = .{
        .action = .CLEAR,
        .val = .{ 0.0, 0.0, 0.0, 1.0 }
    };

    // create a dynamic vertex buffer for the tile and sprite quads
    state.gfx.offscreen.vbuf = sg.makeBuffer(.{
        .usage = .STREAM,
        .size = @sizeOf(@TypeOf(state.gfx.vertices))
    });

    // create a quad-vertex-buffer for rendering the offscreen render target to the display
    const quad_verts = [_]f32{ 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0 };
    state.gfx.display.quad_vbuf = sg.makeBuffer(.{
        .content = &quad_verts,
        .size = @sizeOf(@TypeOf(quad_verts))
    });

    // create pipeline and shader for rendering into offscreen render target
    {
        var shd_desc: sg.ShaderDesc = .{};
        shd_desc.attrs[0] = .{ .name = "pos", .sem_name = "POSITION" };
        shd_desc.attrs[1] = .{ .name = "uv_in", .sem_name = "TEXCOORD", .sem_index = 0 };
        shd_desc.attrs[2] = .{ .name = "data_in", .sem_name = "TEXCOORD", .sem_index = 1 };
        shd_desc.fs.images[0] = .{ .name = "tile_tex", .type = ._2D };
        shd_desc.fs.images[1] = .{ .name = "pal_tex", .type = ._2D };
        shd_desc.vs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => GLCore33.Offscreen.VertexShader,
            else => unreachable,
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => GLCore33.Offscreen.FragmentShader,
            else => unreachable,
        };
        var pip_desc: sg.PipelineDesc = .{
            .shader = sg.makeShader(shd_desc),
            .blend = .{
                .enabled = true,
                .color_format = .RGBA8,
                .depth_format = .NONE,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA
            }
        };
        pip_desc.layout.attrs[0].format = .FLOAT2;
        pip_desc.layout.attrs[1].format = .FLOAT2;
        pip_desc.layout.attrs[2].format = .UBYTE4N;
        state.gfx.offscreen.pip = sg.makePipeline(pip_desc);
    }

    // create pipeline and shader for rendering into display
    {
        var shd_desc: sg.ShaderDesc = .{};
        shd_desc.attrs[0] = .{ .name = "pos", .sem_name = "POSITION" };
        shd_desc.fs.images[0] = .{ .name = "tex", .type = ._2D };
        shd_desc.vs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => GLCore33.Display.VertexShader,
            else => unreachable
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => GLCore33.Display.FragmentShader,
            else => unreachable
        };
        var pip_desc: sg.PipelineDesc = .{
            .shader = sg.makeShader(shd_desc),
            .primitive_type = .TRIANGLE_STRIP,
        };
        pip_desc.layout.attrs[0].format = .FLOAT2;
        state.gfx.display.pip = sg.makePipeline(pip_desc);
    }
}

//--- sokol-app callbacks ------------------------------------------------------
export fn init() void {
    gfxInit();
}

export fn frame() void {
    sg.beginDefaultPass(state.gfx.pass_action, sapp.width(), sapp.height());
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    gfxShutdown();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = 2 * DisplayPixelsX,
        .height = 2 * DisplayPixelsY,
        .window_title = "pacman.zig"
    });
}

// platform-specific shader sources:
const GLCore33 = struct {
    const Offscreen = struct {
        const VertexShader =
            \\ #version 330
            \\ layout(location=0) in vec4 pos;
            \\ layout(location=1) in vec2 uv_in;
            \\ layout(location=2) in vec4 data_in;
            \\ out vec2 uv;
            \\ out vec4 data;
            \\ void main() {
            \\   gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
            \\   uv = uv_in;
            \\   data = data_in;
            \\ }
            ;
        const FragmentShader =
            \\ #version 330
            \\ uniform sampler2D tile_tex;
            \\ uniform sampler2D pal_tex;
            \\ in vec2 uv;
            \\ in vec4 data;
            \\ out vec4 frag_color;
            \\ void main() {
            \\   float color_code = data.x;
            \\   float tile_color = texture(tile_tex, uv).x;
            \\   vec2 pal_uv = vec2(color_code * 4 + tile_color, 0);
            \\   frag_color = texture(pal_tex, pal_uv) * vec4(1, 1, 1, data.y);
            \\ }
            ;
    };
    const Display = struct {
        const VertexShader =
            \\ #version 330
            \\ layout(location=0) in vec4 pos;
            \\ out vec2 uv;
            \\ void main() {
            \\   gl_Position = vec4((pos.xy - 0.5) * 2.0, 0.0, 1.0);
            \\   uv = pos.xy;
            \\ }
            ;
        const FragmentShader =
            \\ #version 330
            \\ uniform sampler2D tex;
            \\ in vec2 uv;
            \\ out vec4 frag_color;
            \\ void main() {
            \\   frag_color = texture(tex, uv);
            \\ }
            ;
    };
};
