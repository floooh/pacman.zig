const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;

// embedded Pacman arcade machine ROM dumps
const TileRom = @embedFile("roms/pacman_tiles.rom");
const SpriteRom = @embedFile("roms/pacman_sprites.rom");
const ColorRom = @embedFile("roms/pacman_hwcolors.rom");
const PaletteRom = @embedFile("roms/pacman_palette.rom");

// various constants
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
const TileTextureWidth = 256 * TileWidth;
const TileTextureHeight = TileHeight + SpriteHeight;
const MaxVertices = ((DisplayTilesX*DisplayTilesY) + NumSprites + NumDebugMarkers) * 6;

// all mutable state is in a single nested global
const State = struct {
    gfx: Gfx = .{},
};
var state: State = .{};

//--- rendering subsystem ------------------------------------------------------
const Gfx = struct {
    // vertex-structure for rendering background tiles and sprites
    const Vertex = packed struct {
        x: f32, y: f32,     // 2D-pos
        u: f32, v: f32,     // texcoords
        attr: u32,          // color code and opacity
    };

    // current fade opacity
    fade: u8 = 0,

    pass_action: sg.PassAction = .{},

    offscreen: struct {
        vbuf: sg.Buffer = .{},
        tile_img: sg.Image = .{},
        palette_img: sg.Image = .{},
        render_target: sg.Image = .{},
        pip: sg.Pipeline = .{},
        pass: sg.Pass = .{},
        bind: sg.Bindings = .{},
    } = .{},
    
    display: struct {
        quad_vbuf: sg.Buffer = .{},
        pip: sg.Pipeline = .{},
        bind: sg.Bindings = .{},
    } = .{},

    // upload-buffer for dynamically generated tile- and sprite-vertices
    num_vertices: i32 = 0,
    vertices: [MaxVertices]Vertex = undefined,

    // scratch-space for decoding tile ROM dumps into a GPU texture
    tile_pixels: [TileTextureHeight][TileTextureWidth]u8 = undefined,
    
    // scratch space for decoding color+palette ROM dumps into a GPU texture
    color_palette: [256]u32 = undefined,
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
    gfxDecodeTiles();
    gfxDecodeColorPalette();
    gfxCreateResources();
}

fn gfxShutdown() void {
    sg.shutdown();
}

fn gfxDrawFrame() void {
    // handle fade-in/out
    gfxFade();

    // render tile- and sprite-vertices and upload into vertex buffer
    state.gfx.num_vertices = 0;
    gfxAddPlayfieldVertices();
    gfxAddSpriteVertices();
    gfxAddDebugMarkerVertices();
    if (state.gfx.fade > 0) {
        gfxAddFadeVertices();
    }
    sg.updateBuffer(state.gfx.offscreen.vbuf, &state.gfx.vertices, @intCast(i32, state.gfx.num_vertices * @sizeOf(Gfx.Vertex)));

    // render tiles and sprites into offscreen render target
    sg.beginPass(state.gfx.offscreen.pass, state.gfx.pass_action);
    sg.applyPipeline(state.gfx.offscreen.pip);
    sg.applyBindings(state.gfx.offscreen.bind);
    sg.draw(0, state.gfx.num_vertices, 1);
    sg.endPass();

    // upscale-render the offscreen render target into the display framebuffer
    const canvas_width = sapp.width();
    const canvas_height = sapp.height();
    sg.beginDefaultPass(state.gfx.pass_action, canvas_width, canvas_height);
    sg.applyPipeline(state.gfx.display.pip);
    sg.applyBindings(state.gfx.display.bind);
    sg.draw(0, 4, 1);
    sg.endPass();
    sg.commit();
}

fn gfxFade() void {
    // FIXME
}

fn gfxAddPlayfieldVertices() void {
    // FIXME
}

fn gfxAddSpriteVertices() void {
    // FIXME
}

fn gfxAddDebugMarkerVertices() void {
    // FIXME
}

fn gfxAddFadeVertices() void {

}

//  8x4 tile decoder (taken from: https://github.com/floooh/chips/blob/master/systems/namco.h)
//
//  This decodes 2-bit-per-pixel tile data from Pacman ROM dumps into
//  8-bit-per-pixel texture data (without doing the RGB palette lookup,
//  this happens during rendering in the pixel shader).
//
//  The Pacman ROM tile layout isn't exactly strightforward, both 8x8 tiles
//  and 16x16 sprites are built from 8x4 pixel blocks layed out linearly
//  in memory, and to add to the confusion, since Pacman is an arcade machine
//  with the display 90 degree rotated, all the ROM tile data is counter-rotated.
//
//  Tile decoding only happens once at startup from ROM dumps into a texture.
//
fn gfxDecodeTile8x4(
    tile_code: u32,     // the source tile code
    src: []const u8,    // encoded source tile data
    src_stride: u32,    // stride and offset in encoded tile data
    src_offset: u32,
    dst_x: u32,         // x/y position in target texture
    dst_y: u32)
void {
    var x: u32 = 0;
    while (x < TileWidth): (x += 1) {
        const ti = tile_code * src_stride + src_offset + (7 - x);
        var y: u3 = 0;
        while (y < (TileHeight/2)): (y += 1) {
            const p_hi: u8 = (src[ti] >> (7 - y)) & 1;
            const p_lo: u8 = (src[ti] >> (3 - y)) & 1;
            const p: u8 = (p_hi << 1) | p_lo;
            state.gfx.tile_pixels[dst_y + y][dst_x + x] = p;
        }
    }
}

// decode an 8x8 tile into the tile texture upper 8 pixels
fn gfxDecodeTile(tile_code: u32) void {
    const x = tile_code * TileWidth;
    const y0 = 0;
    const y1 = TileHeight / 2;
    gfxDecodeTile8x4(tile_code, TileRom, 16, 8, x, y0);
    gfxDecodeTile8x4(tile_code, TileRom, 16, 0, x, y1);
}

// decode a 16x16 sprite into the tile textures lower 16 pixels
fn gfxDecodeSprite(sprite_code: u32) void {
    const x0 = sprite_code * SpriteWidth;
    const x1 = x0 + TileWidth;
    const y0 = TileHeight;
    const y1 = y0 + (TileHeight / 2);
    const y2 = y1 + (TileHeight / 2);
    const y3 = y2 + (TileHeight / 2);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 40, x0, y0);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64,  8, x1, y0);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 48, x0, y1);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 16, x1, y1);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 56, x0, y2);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 24, x1, y2);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64, 32, x0, y3);
    gfxDecodeTile8x4(sprite_code, SpriteRom, 64,  0, x1, y3);
}

// decode the Pacman tile- and sprite-ROM-dumps into an 8-bpp linear texture
fn gfxDecodeTiles() void {
    var tile_code: u32 = 0;
    while (tile_code < 256): (tile_code += 1) {
        gfxDecodeTile(tile_code);
    }
    var sprite_code: u32 = 0;
    while (sprite_code < 64): (sprite_code += 1) {
        gfxDecodeSprite(sprite_code);
    }
    // write a special 16x16 block which will be used for the fade effect
    var y: u32 = TileHeight;
    while (y < TileTextureHeight): (y += 1) {
        var x: u32 = 64 * SpriteWidth;
        while (x < (65 * SpriteWidth)): (x += 1) {
            state.gfx.tile_pixels[y][x] = 1;
        }
    }
}

// decode the Pacman color palette into a palette texture, on the original
// hardware, color lookup happens in two steps, first through 256-entry
// palette which indirects into a 32-entry hardware-color palette
// (of which only 16 entries are used on the Pacman hardware)
//
fn gfxDecodeColorPalette() void {
    // Expand the 8-bit palette ROM items into RGBA8 items.
    // The 8-bit palette item bits are packed like this:
    // 
    // | 7| 6| 5| 4| 3| 2| 1| 0|
    // |B1|B0|G2|G1|G0|R2|R1|R0|
    //
    // Intensities for the 3 bits are: 0x97 + 0x47 + 0x21
    var hw_colors: [32]u32 = undefined;
    for (hw_colors) |*pt, i| {
        const rgb = ColorRom[i];
        const r: u32 = ((rgb>>0)&1)*0x21 + ((rgb>>1)&1)*0x47 + ((rgb>>2)&1)*0x97;
        const g: u32 = ((rgb>>3)&1)*0x21 + ((rgb>>4)&1)*0x47 + ((rgb>>5)&1)*0x97;
        const b: u32 =                     ((rgb>>6)&1)*0x47 + ((rgb>>7)&1)*0x97;
        pt.* = 0xFF_00_00_00 | (b<<16) | (g<<8) | r;
    }

    // build 256-entry from indirection palette ROM
    for (state.gfx.color_palette) |*pt, i| {
        pt.* = hw_colors[PaletteRom[i] & 0xF];
        // first color in each color block is transparent
        if ((i & 3) == 0) {
            pt.* &= 0x00_FF_FF_FF;
        }
    }
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
    // NOTE: initializating structs with embedded arrays isn't great yet in Zig
    // because arrays aren't "filled up" with default items.
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

    // create a render-target image with a fixed upscale ratio
    state.gfx.offscreen.render_target = sg.makeImage(.{
        .render_target = true,
        .width = DisplayPixelsX * 2,
        .height = DisplayPixelsY * 2,
        .pixel_format = .RGBA8,
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
        .wrap_u = .CLAMP_TO_EDGE,
        .wrap_v = .CLAMP_TO_EDGE
    });

    // a pass object for rendering into the offscreen render target
    {
        var pass_desc: sg.PassDesc = .{};
        pass_desc.color_attachments[0].image = state.gfx.offscreen.render_target;
        state.gfx.offscreen.pass = sg.makePass(pass_desc);
    }

    // create the decoded tile+sprite texture
    {
        var img_desc: sg.ImageDesc = .{
            .width = TileTextureWidth,
            .height = TileTextureHeight,
            .pixel_format = .R8,
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
            .wrap_u = .CLAMP_TO_EDGE,
            .wrap_v = .CLAMP_TO_EDGE,
        };
        img_desc.content.subimage[0][0] = .{
            .ptr = &state.gfx.tile_pixels,
            .size = @sizeOf(@TypeOf(state.gfx.tile_pixels))
        };
        state.gfx.offscreen.tile_img = sg.makeImage(img_desc);
    }

    // create the color-palette texture
    {
        var img_desc: sg.ImageDesc = .{
            .width = 256,
            .height = 1,
            .pixel_format = .RGBA8,
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
            .wrap_u = .CLAMP_TO_EDGE,
            .wrap_v = .CLAMP_TO_EDGE,
        };
        img_desc.content.subimage[0][0] = .{
            .ptr = &state.gfx.color_palette,
            .size = @sizeOf(@TypeOf(state.gfx.color_palette))
        };
        state.gfx.offscreen.palette_img = sg.makeImage(img_desc);
    }

    // setup resource binding structs
    state.gfx.offscreen.bind.vertex_buffers[0] = state.gfx.offscreen.vbuf;
    state.gfx.offscreen.bind.fs_images[0] = state.gfx.offscreen.tile_img;
    state.gfx.offscreen.bind.fs_images[1] = state.gfx.offscreen.palette_img;
    state.gfx.display.bind.vertex_buffers[0] = state.gfx.display.quad_vbuf;
    state.gfx.display.bind.fs_images[0] = state.gfx.offscreen.render_target;
}

//--- sokol-app callbacks ------------------------------------------------------
export fn init() void {
    gfxInit();
}

export fn frame() void {
    gfxDrawFrame();
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
