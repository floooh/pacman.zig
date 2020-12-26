const sg = @import("sokol").gfx;
const sapp = @import("sokol").app;
const stm = @import("sokol").time;
const sgapp = @import("sokol").app_gfx_glue;
const assert = @import("std").debug.assert;

const warn = @import("std").debug.warn;

// debugging options
const DbgSkipIntro = false;         // set to true to skip intro gamestate
const DbgSkipPrelude = false;       // set to true to skip prelude at start of gameloop
const DbgStartRound = 0;            // set to any starting round <= 255
const DbgShowMarkers = false;       // set to true to display debug markers
const DbgEscape = false;            // set to true to end game round with Escape
const DbgDoubleSpeed = false;       // set to true to speed up game
const DbgGodMode = false;           // set to true to make Pacman invulnerable

// various constants
const TickDurationNS = if (DbgDoubleSpeed) 8_333_33 else 16_666_667;
const MaxFrameTimeNS = 33_333_333.0;    // max duration of a frame in nanoseconds
const TickToleranceNS = 1_000_000;      // max time tolerance of a game tick in nanoseconds
const FadeTicks = 30;                   // fade in/out duration in game ticks
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

// common tile codes
const TileCodeSpace      = 0x40;
const TileCodeDot        = 0x10;
const TileCodePill       = 0x14;
const TileCodeGhost      = 0xB0;
const TileCodeLife       = 0x20; // 0x20..0x23
const TileCodeCherries   = 0x90; // 0x90..0x93
const TileCodeStrawberry = 0x94; // 0x94..0x97
const TileCodePeach      = 0x98; // 0x98..0x9B
const TileCodeBell       = 0x9C; // 0x9C..0x9F
const TileCodeApple      = 0xA0; // 0xA0..0xA3
const TileCodeGrapes     = 0xA4; // 0xA4..0xA7
const TileCodeGalaxian   = 0xA8; // 0xA8..0xAB
const TileCodeKey        = 0xAC; // 0xAC..0xAF
const TileCodeDoor       = 0xCF; // the ghost-house door

// common sprite tile codes
const SpriteCodeInvisible    = 30;
const SpriteCodeScore200     = 40;
const SpriteCodeScore400     = 41;
const SpriteCodeScore800     = 42;
const SpriteCodeScore1600    = 43;
const SpriteCodeCherries     = 0;
const SpriteCodeStrawberry   = 1;
const SpriteCodePeach        = 2;
const SpriteCodeBell         = 3;
const SpriteCodeApple        = 4;
const SpriteCodeGrapes       = 5;
const SpriteCodeGalaxian     = 6;
const SpriteCodeKey          = 7;
const SpriteCodePacmanClosedMouth = 48;

// common color codes
const ColorCodeBlank         = 0x00;
const ColorCodeDefault       = 0x0F;
const ColorCodeDot           = 0x10;
const ColorCodePacman        = 0x09;
const ColorCodeBlinky        = 0x01;
const ColorCodePinky         = 0x03;
const ColorCodeInky          = 0x05;
const ColorCodeClyde         = 0x07;
const ColorCodeFrightened    = 0x11;
const ColorCodeFrightenedBlinking = 0x12;
const ColorCodeGhostScore    = 0x18;
const ColorCodeEyes          = 0x19;
const ColorCodeCherries      = 0x14;
const ColorCodeStrawberry    = 0x0F;
const ColorCodePeach         = 0x15;
const ColorCodeBell          = 0x16;
const ColorCodeApple         = 0x14;
const ColorCodeGrapes        = 0x17;
const ColorCodeGalaxian      = 0x09;
const ColorCodeKey           = 0x16;
const ColorCodeWhiteBorder   = 0x1F;
const ColorCodeFruitScore    = 0x03;

// all mutable state is in a single nested global
const State = struct {
    timing: struct {
        tick: u32 = 0,
        laptime_store: u64 = 0,
        tick_accum: i32 = 0,
    } = .{},
    gamestate: GameState = undefined,
    input: Input = .{},
    intro: Intro = .{},
    game: Game = .{},
    gfx: Gfx = .{},
};
var state: State = .{};

// a 2D integer vector type
const ivec2 = @Vector(2,i16);

//--- gameplay system ----------------------------------------------------------
const GameState = enum {
    Intro,
    Game,
};

const Dir = enum {
    Right,
    Down,
    Left,
    Up,

    fn reverse(self: Dir) Dir {
        return switch (self) {
            .Right => .Left,
            .Down => .Up,
            .Left => .Right,
            .Up => .Down,
        };
    }
};

//--- Game gamestate -----------------------------------------------------------
const Game = struct {
    hiscore: u32 = 0,
    started: Trigger = .{},
};

fn gameTick() void {
    // FIXME
}

//--- Intro gamestate ----------------------------------------------------------
const Intro = struct {
    started: Trigger = .{},
};

fn introTick() void {
    // on state enter, enable input and draw initial text
    if (state.intro.started.now()) {
        // sndClear();
        gfxClearSprites();
        state.gfx.fadein.start();
        state.input.enable();
        gfxClear(TileCodeSpace, ColorCodeDefault);
        gfxText(.{3,0}, "1UP   HIGH SCORE   2UP");
        //gfxColorScore(.{6,1}, ColorDefault, 0);
        if (state.game.hiscore > 0) {
            //gfxColorScore(.{16,1}, ColorCodeDefault, state.game.hiscore);
        }
        gfxText(.{7,5}, "CHARACTER / NICKNAME");
        gfxText(.{3,35}, "CREDIT 0");
    }

    // if a key is pressed, advance to game state
    if (state.input.anykey) {
        state.input.disable();
        state.gfx.fadeout.start();
        state.game.started.startAfter(FadeTicks);
    }
}

//--- input system -------------------------------------------------------------
const Input = struct {
    enabled: bool = false,
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    esc: bool = false,
    anykey: bool = false,

    fn enable(self: *Input) void {
        self.enabled = true;
    }
    fn disable(self: *Input) void {
        self.* = .{};
    }
    fn dir(self: *Input, default_dir: Dir) Dir {
        if (self.enabled) {
            if (self.up) { return .Up; }
            else if (self.down) { return .Down; }
            else if (self.left) { return .Left; }
            else if (self.right) { return .Right; }
        }
        return default_dir;
    }
    fn onKey(self: *Input, keycode: sapp.Keycode, key_pressed: bool) void {
        if (self.enabled) {
            self.anykey = key_pressed;
            switch (keycode) {
                .W, .UP,    => self.up = key_pressed,
                .S, .DOWN,  => self.down = key_pressed,
                .A, .LEFT,  => self.left = key_pressed,
                .D, .RIGHT, => self.right = key_pressed,
                .ESCAPE     => self.esc = key_pressed,
                else => {}
            }
        }
    }
};

//--- time-trigger system ------------------------------------------------------
const Trigger = struct {
    const DisabledTicks = 0xFF_FF_FF_FF;

    tick: u32 = DisabledTicks,

    // set trigger to next tick
    fn start(t: *Trigger) void {
        t.tick = state.timing.tick + 1;
    }
    // set trigger to a future tick
    fn startAfter(t: *Trigger, ticks: u32) void {
        t.tick = state.timing.tick + ticks;
    }
    // disable a trigger
    fn disable(t: *Trigger) void {
        t.ticks = DisabledTicks;
    }
    // check if trigger is triggered in current game tick
    fn now(t: Trigger) bool {
        return t.tick == state.timing.tick;
    }
    // return number of ticks since a time trigger was triggered
    fn since(t: Trigger) u32 {
        if (state.timing.tick >= t.tick) {
            return state.timing.tick - t.tick;
        }
        else {
            return DisabledTicks;
        }
    }
    // check if a time trigger is between begin and end tick
    fn between(t: Trigger, begin: u32, end: u32) bool {
        assert(begin < end);
        if (t.tick != DisabledTicks) {
            const ticks = since(t);
            return (ticks >= begin) and (ticks < end);
        }
        else {
            return false;
        }
    }
    // check if a time trigger was triggered exactly N ticks ago
    fn afterOnce(t: Trigger, ticks: u32) bool {
        return since(t) == ticks;
    }
    // check if a time trigger was triggered more than N ticks ago
    fn after(t: Trigger, ticks, u32) bool {
        const s = since(t);
        if (s != DisabledTicks) {
            return s >= ticks;
        }
        else {
            return false;
        }
    }
    // same as between(t, 0, ticks)
    fn before(t: Trigger, ticks: u32) bool {
        const s = since(t);
        if (s != DisabledTicks) {
            return s < ticks;
        }
        else {
            return false;
        }
    }
};

//--- rendering system ---------------------------------------------------------
const Gfx = struct {
    // vertex-structure for rendering background tiles and sprites
    const Vertex = packed struct {
        x: f32, y: f32,     // 2D-pos
        u: f32, v: f32,     // texcoords
        attr: u32,          // color code and opacity
    };

    // a 'hardware sprite' struct
    const Sprite = struct {
        enabled: bool = false,
        tile: u8 = 0,
        color: u8 = 0,
        flipx: bool = false,
        flipy: bool = false,
        pos: ivec2 = ivec2{0,0},
    };

    // fade in/out
    fadein: Trigger = .{},
    fadeout: Trigger = .{},
    fade: u8 = 0xFF,

    // 'hardware sprites' (meh, array default initialization sure looks awkward...)
    sprites: [NumSprites]Sprite = [_]Sprite{.{}} ** NumSprites,

    // tile- and color-buffer
    tile_ram: [DisplayTilesY][DisplayTilesX]u8 = undefined,
    color_ram: [DisplayTilesY][DisplayTilesX]u8 = undefined,

    // sokol-gfx objects
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
    num_vertices: u32 = 0,
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

fn gfxClear(tile_code: u8, color_code: u8) void {
    var y: u32 = 0;
    while (y < DisplayTilesY): (y += 1) {
        var x: u32 = 0;
        while (x < DisplayTilesX): (x += 1) {
            state.gfx.tile_ram[y][x] = tile_code;
            state.gfx.color_ram[y][x] = color_code;
        }
    }
}

fn gfxTile(pos: ivec2, tile_code: u8) void {
    state.gfx.tile_ram[@intCast(usize,pos[1])][@intCast(usize,pos[0])] = tile_code;
}

fn gfxColor(pos: ivec2, color_code: u8) void {
    state.gfx.color_ram[@intCast(usize,pos[1])][@intCast(usize,pos[0])] = color_code;
}

fn gfxColorTile(pos: ivec2, color_code: u8, tile_code: u8) void {
    gfxTile(pos, tile_code);
    gfxColor(pos, color_code);
}

fn gfxToNamcoChar(c: u8) u8 {
    return switch (c) {
        ' ' => 64,
        '/' => 58,
        '-' => 59,
        '"' => 38,
        '!' => 'Z'+1,
        else => c
    };
}

fn gfxChar(pos: ivec2, chr: u8) void {
    gfxTile(pos, gfxToNamcoChar(chr));
}

fn gfxColorChar(pos: ivec2, color_code: u8, chr: u8) void {
    gfxChar(pos, chr);
    gfxColor(pos, color_code);
}

fn gfxColorText(pos: ivec2, color_code: u8, text: []const u8) void {
    var p = pos;
    for (text) |chr| {
        if (p[0] < DisplayTilesX) {
            gfxColorChar(p, color_code, chr);
            p[0] += 1;
        }
        else {
            break;
        }
    }
}

fn gfxText(pos: ivec2, text: []const u8) void {
    var p = pos;
    for (text) |chr| {
        if (p[0] < DisplayTilesX) {
            gfxChar(p, chr);
            p[0] += 1;
        }
        else {
            break;
        }
    }
}

fn gfxClearSprites() void {
    for (state.gfx.sprites) |*spr| {
        spr.* = .{};
    }
}

fn gfxFrame() void {
    // handle fade-in/out
    gfxUpdateFade();

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
    // FIXME: sokol-gfx should use unsigned params here
    sg.draw(0, @intCast(i32, state.gfx.num_vertices), 1);
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

fn gfxAddVertex(x: f32, y: f32, u: f32, v: f32, color_code: u32, opacity: u32) void {
    var vtx: *Gfx.Vertex = &state.gfx.vertices[state.gfx.num_vertices];
    state.gfx.num_vertices += 1;
    vtx.x = x;
    vtx.y = y;
    vtx.u = u;
    vtx.v = v;
    vtx.attr = (opacity<<8)|color_code;
}

fn gfxAddTileVertices(x: u32, y: u32, tile_code: u32, color_code: u32) void {
    const dx = 1.0 / @intToFloat(f32, DisplayTilesX);
    const dy = 1.0 / @intToFloat(f32, DisplayTilesY);
    const dtx = @intToFloat(f32, TileWidth) / TileTextureWidth;
    const dty = @intToFloat(f32, TileHeight) / TileTextureHeight;

    const x0 = @intToFloat(f32, x) * dx;
    const x1 = x0 + dx;
    const y0 = @intToFloat(f32, y) * dy;
    const y1 = y0 + dy;
    const tx0 = @intToFloat(f32, tile_code) * dtx;
    const tx1 = tx0 + dtx;
    const ty0: f32 = 0.0;
    const ty1 = dty;

    //  x0,y0
    //  +-----+
    //  | *   |
    //  |   * |
    //  +-----+
    //          x1,y1
    gfxAddVertex(x0, y0, tx0, ty0, color_code, 0xFF);
    gfxAddVertex(x1, y0, tx1, ty0, color_code, 0xFF);
    gfxAddVertex(x1, y1, tx1, ty1, color_code, 0xFF);
    gfxAddVertex(x0, y0, tx0, ty0, color_code, 0xFF);
    gfxAddVertex(x1, y1, tx1, ty1, color_code, 0xFF);
    gfxAddVertex(x0, y1, tx0, ty1, color_code, 0xFF);
}

fn gfxUpdateFade() void {
    if (state.gfx.fadein.before(FadeTicks)) {
        const t = @intToFloat(f32, state.gfx.fadein.since()) / FadeTicks;
        state.gfx.fade = @floatToInt(u8, 255.0 * (1.0 - t));
    }
    if (state.gfx.fadein.afterOnce(FadeTicks)) {
        state.gfx.fade = 0;
    }
    if (state.gfx.fadeout.before(FadeTicks)) {
        const t = @intToFloat(f32, state.gfx.fadeout.since()) / FadeTicks;
        state.gfx.fade = @floatToInt(u8, 255.0 * t);
    }
    if (state.gfx.fadeout.afterOnce(FadeTicks)) {
        state.gfx.fade = 255;
    }
}

fn gfxAddPlayfieldVertices() void {
    var y: u32 = 0;
    while (y < DisplayTilesY): (y += 1) {
        var x: u32 = 0;
        while (x < DisplayTilesX): (x += 1) {
            const tile_code = state.gfx.tile_ram[y][x];
            const color_code = state.gfx.color_ram[y][x] & 0x1F;
            gfxAddTileVertices(x, y, tile_code, color_code);
        }
    }
}

fn gfxAddSpriteVertices() void {
    const dx = 1.0 / @intToFloat(f32, DisplayPixelsX);
    const dy = 1.0 / @intToFloat(f32, DisplayPixelsY);
    const dtx = @intToFloat(f32, SpriteWidth) / TileTextureWidth;
    const dty = @intToFloat(f32, SpriteHeight) / TileTextureHeight;
    for (state.gfx.sprites) |*spr| {
        if (spr.enabled) {
            const xx0 = @intToFloat(f32, spr.pos[0]) * dx;
            const xx1 = xx0 + dx*SpriteWidth;
            const yy0 = @intToFloat(f32, spr.pos[1]) * dy;
            const yy1 = yy0 + dy*SpriteHeight;

            const x0 = if (spr.flipx) xx1 else xx0;
            const x1 = if (spr.flipx) xx0 else xx1;
            const y0 = if (spr.flipy) yy1 else yy0;
            const y1 = if (spr.flipy) yy0 else yy1;

            const tx0 = @intToFloat(f32, spr.tile) * dtx;
            const tx1 = tx0 + dtx;
            const ty0 = @intToFloat(f32, TileHeight) / TileTextureHeight;
            const ty1 = ty0 + dty;

            gfxAddVertex(x0, y0, tx0, ty0, spr.color, 0xFF);
            gfxAddVertex(x1, y0, tx1, ty0, spr.color, 0xFF);
            gfxAddVertex(x1, y1, tx1, ty1, spr.color, 0xFF);
            gfxAddVertex(x0, y0, tx0, ty0, spr.color, 0xFF);
            gfxAddVertex(x1, y1, tx1, ty1, spr.color, 0xFF);
            gfxAddVertex(x0, y1, tx0, ty1, spr.color, 0xFF);
        }
    }
}

fn gfxAddDebugMarkerVertices() void {
    // FIXME
}

fn gfxAddFadeVertices() void {
    // sprite tile 64 is a special opaque sprite
    const dtx = @intToFloat(f32, SpriteWidth) / TileTextureWidth;
    const dty = @intToFloat(f32, SpriteHeight) / TileTextureHeight;
    const tx0 = 64 * dtx;
    const tx1 = tx0 + dtx;
    const ty0 = @intToFloat(f32, TileHeight) / TileTextureHeight;
    const ty1 = ty0 + dty;

    const fade = state.gfx.fade;
    gfxAddVertex(0.0, 0.0, tx0, ty0, 0, fade);
    gfxAddVertex(1.0, 0.0, tx1, ty0, 0, fade);
    gfxAddVertex(1.0, 1.0, tx1, ty1, 0, fade);
    gfxAddVertex(0.0, 0.0, tx0, ty0, 0, fade);
    gfxAddVertex(1.0, 1.0, tx1, ty1, 0, fade);
    gfxAddVertex(0.0, 1.0, tx0, ty1, 0, fade);
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
const TileRom = @embedFile("roms/pacman_tiles.rom");
fn gfxDecodeTile(tile_code: u32) void {
    const x = tile_code * TileWidth;
    const y0 = 0;
    const y1 = TileHeight / 2;
    gfxDecodeTile8x4(tile_code, TileRom, 16, 8, x, y0);
    gfxDecodeTile8x4(tile_code, TileRom, 16, 0, x, y1);
}

// decode a 16x16 sprite into the tile textures lower 16 pixels
const SpriteRom = @embedFile("roms/pacman_sprites.rom");
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
    const color_rom = @embedFile("roms/pacman_hwcolors.rom");
    var hw_colors: [32]u32 = undefined;
    for (hw_colors) |*pt, i| {
        const rgb = color_rom[i];
        const r: u32 = ((rgb>>0)&1)*0x21 + ((rgb>>1)&1)*0x47 + ((rgb>>2)&1)*0x97;
        const g: u32 = ((rgb>>3)&1)*0x21 + ((rgb>>4)&1)*0x47 + ((rgb>>5)&1)*0x97;
        const b: u32 =                     ((rgb>>6)&1)*0x47 + ((rgb>>7)&1)*0x97;
        pt.* = 0xFF_00_00_00 | (b<<16) | (g<<8) | r;
    }

    // build 256-entry from indirection palette ROM
    const palette_rom = @embedFile("roms/pacman_palette.rom");
    for (state.gfx.color_palette) |*pt, i| {
        pt.* = hw_colors[palette_rom[i] & 0xF];
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
            .GLCORE33 => @embedFile("shaders/offscreen_vs.v330.glsl"),
            else => unreachable,
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => @embedFile("shaders/offscreen_fs.v330.glsl"),
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
            .GLCORE33 => @embedFile("shaders/display_vs.v330.glsl"),
            else => unreachable
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11 => undefined,
            .GLCORE33 => @embedFile("shaders/display_fs.v330.glsl"),
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
    stm.setup();
    gfxInit();
    if (DbgSkipIntro) {
        state.game.started.start();
    }
    else {
        state.intro.started.start();
    }
}

export fn frame() void {

    // run the game at a fixed tick rate regardless of frame rate
    var frame_time_ns = stm.ns(stm.laptime(&state.timing.laptime_store));
    // clamp max frame duration (so the timing isn't messed up when stepping in debugger)
    if (frame_time_ns > MaxFrameTimeNS) {
        frame_time_ns = MaxFrameTimeNS;
    }

    state.timing.tick_accum += @floatToInt(i32, frame_time_ns);
    while (state.timing.tick_accum > -TickToleranceNS) {
        state.timing.tick_accum -= TickDurationNS;
        state.timing.tick += 1;

        // check for game state change
        if (state.intro.started.now()) {
            state.gamestate = .Intro;
        }
        if (state.game.started.now()) {
            state.gamestate = .Game;
        }

        // call the top-level gamestate tick function
        switch (state.gamestate) {
            .Intro => introTick(),
            .Game => gameTick(),
        }
    }
    gfxFrame();
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    if ((event.type == .KEY_DOWN) or (event.type == .KEY_UP)) {
        const key_pressed = event.type == .KEY_DOWN;
        state.input.onKey(event.key_code, key_pressed);
    }
}

export fn cleanup() void {
    gfxShutdown();
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = input,
        .cleanup_cb = cleanup,
        .width = 2 * DisplayPixelsX,
        .height = 2 * DisplayPixelsY,
        .window_title = "pacman.zig"
    });
}
