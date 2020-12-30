const sg     = @import("sokol").gfx;
const sapp   = @import("sokol").app;
const sgapp  = @import("sokol").app_gfx_glue;
const stm    = @import("sokol").time;
const saudio = @import("sokol").audio;
const assert = @import("std").debug.assert;
const math   = @import("std").math;

// debugging and config options
const AudioVolume = 0.5;
const DbgSkipIntro = false;         // set to true to skip intro gamestate
const DbgSkipPrelude = false;       // set to true to skip prelude at start of gameloop
const DbgStartRound = 0;            // set to any starting round <= 255
const DbgShowMarkers = false;       // set to true to display debug markers
const DbgEscape = false;            // set to true to end game round with Escape
const DbgDoubleSpeed = false;       // set to true to speed up game
const DbgGodMode = false;           // set to true to make Pacman invulnerable

// misc constants
const TickDurationNS = if (DbgDoubleSpeed) 8_333_33 else 16_666_667;
const MaxFrameTimeNS = 33_333_333.0;    // max duration of a frame in nanoseconds
const TickToleranceNS = 1_000_000;      // max time tolerance of a game tick in nanoseconds
const FadeTicks = 30;                   // fade in/out duration in game ticks
const NumDebugMarkers = 16;
const NumLives = 3;
const NumGhosts = 4;
const NumDots = 244;
const NumPills = 4;
const AntePortasX = 14*TileWidth;   // x/y position of ghost hour entry
const AntePortasY = 14*TileHeight + TileHeight/2;
const FruitActiveTicks = 10 * 60;   // number of ticks the bonus fruit is shown
const GhostEatenFreezeTicks = 60;   // number of ticks the game freezes after Pacman eats a ghost
const PacmanEatenTicks = 60;        // number of ticks the game freezes after Pacman gets eaten
const PacmanDeathTicks = 150;       // number of ticks to show the Pacman death sequence before starting a new round
const GameOverTicks = 3*60;         // number of ticks to show the Game Over message
const RoundWonTicks = 4*60;         // number of ticks to wait after a round was won

// rendering system constants
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
const NumSprites = 8;
const MaxVertices = ((DisplayTilesX*DisplayTilesY) + NumSprites + NumDebugMarkers) * 6;

// sound system constants
const NumVoices = 3;
const NumSounds = 3;
const NumSamples = 128;

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

// flags for Game.freeze
const FreezePrelude:    u8 = (1<<0);
const FreezeReady:      u8 = (1<<1);
const FreezeEatGhost:   u8 = (1<<2);
const FreezeDead:       u8 = (1<<3);
const FreezeWon:        u8 = (1<<4);

// a 2D vector for pixel- and tile-coordinates
const ivec2 = @Vector(2,i16);

// the game can be either in intro- or game-mode
const GameMode = enum {
    Intro,
    Game,
};

// movement directions
const Dir = enum(u8) {
    Right,
    Down,
    Left,
    Up,
};

// bonus fruit types
const Fruit = enum {
    None,
    Cherries,
    Strawberry,
    Peach,
    Apple,
    Grapes,
    Galaxian,
    Bell,
    Key,
};

// the four ghost types
const GhostType = enum(u8) {
    Blinky,
    Pinky,
    Inky,
    Clyde,
};

// the AI state a ghost is currently in
const GhostState = enum {
    None,
    Chase,      // currently chasing Pacman
    Scatter,    // currently heading towards the corner scatter targets
    Frightened, // frightened after Pacman has eaten an energizer pill
    Eyes,       // eaten by Pacman and heading back to the ghost house
    House,      // currently inside the ghost house
    LeaveHouse, // currently leaving the ghost house
    EnterHouse, // currently entering the ghost house
};

// common ghost and Pacman state
const Actor = struct {
    dir:        Dir = .Right,
    pos:        ivec2 = ivec2{0,0},
    anim_tick:  u32 = 0,
};

// Ghost state
const Ghost = struct {
    actor:          Actor = .{},
    type:           GhostType = .Blinky,
    next_dir:       Dir = .Right,
    target_pos:     ivec2 = ivec2{0,0},
    state:          GhostState = .None,
    frightened:     Trigger = .{},
    eaten:          Trigger = .{},
    dot_counter:    u16 = 0,
    dot_limit:      u16 = 0,
};

// Pacman state
const Pacman = struct {
    actor: Actor = .{},
};

// a time trigger holds a tick at which to start an action
const Trigger = struct {
    const DisabledTicks = 0xFF_FF_FF_FF;
    tick: u32 = DisabledTicks,
};

// a 'hardware sprite' struct
const Sprite = struct {
    enabled:    bool = false,
    tile:       u8 = 0,
    color:      u8 = 0,
    flipx:      bool = false,
    flipy:      bool = false,
    pos:        ivec2 = ivec2{0,0},
};

// a 'debug marker' for visualizing ghost targets
const DebugMarker = struct {
    enabled:    bool = false,
    tile:       u8 = 0,
    color:      u8 = 0,
    tile_pos:   ivec2 = ivec2{0,0},
};

// vertex-structure for rendering background tiles and sprites
const Vertex = packed struct {
    x: f32, y: f32,     // 2D-pos
    u: f32, v: f32,     // texcoords
    attr: u32,          // color code and opacity
};

// callback function signature for procedural sounds
const SoundFunc = fn(usize) void;

// a sound effect description
const SoundDesc = struct {
    func: ?SoundFunc = null,    // optional pointer to sound effect callback if this is a procedural sound
    dump: ?[]const u32 = null,  // optional register dump data slice
    voice: [NumVoices]bool = [_]bool{false} ** NumVoices,
};

// a sound 'hardware voice' (of a Namco WSG emulation)
const Voice = struct {
    counter:    u20 = 0,    // a 20-bit wrap around frequency counter
    frequency:  u20 = 0,    // a 20-bit frequency
    waveform:   u3 = 0,     // a 3-bit waveform index into wavetable ROM dump
    volume:     u4 = 0,     // a 4-bit volume
    sample_acc: f32 = 0.0,
    sample_div: f32 = 0.0,
};

// a sound effect struct
const Sound = struct {
    cur_tick: u32 = 0,          // current 60Hz tick counter
    func: ?SoundFunc = null,    // optional callback for procedural sounds
    dump: ?[]const u32 = null,  // optional register dump data
    num_ticks: u32 = 0,         // sound effect length in ticks (only for register dump sounds)
    stride: u32 = 0,            // register data stride for multivoice dumps (1,2 or 3)
    voice: [NumVoices]bool = [_]bool{false} ** NumVoices,
};

// all mutable state is in a single nested global
const State = struct {
    game_mode: GameMode = .Intro,
    
    timing: struct {
        tick:          u32 = 0,
        laptime_store: u64 = 0,
        tick_accum:    i32 = 0,
    } = .{},

    input:  struct {
        enabled: bool = false,
        up:      bool = false,
        down:    bool = false,
        left:    bool = false,
        right:   bool = false,
        esc:     bool = false,
        anykey:  bool = false,
    } = .{},

    intro: struct {
        started: Trigger = .{},
    } = .{},
    
    game: struct {
        pacman: Pacman = .{},
        ghosts: [NumGhosts]Ghost = [_]Ghost{.{}} ** NumGhosts,

        xorshift:           u32 = 0x12345678,   // xorshift random-number-generator state
        score:              u32 = 0,
        hiscore:            u32 = 0,
        num_lives:          u8 = 0,
        round:              u8 = 0,
        freeze:             u8 = 0,             // combination of Freeze* flags
        num_dots_eaten:     u8 = 0,
        num_ghosts_eaten:   u8 = 0,
        active_fruit:       Fruit = .None,
        
        global_dot_counter_active: bool = false,
        global_dot_counter: u16 = 0,

        started:            Trigger = .{},
        prelude_started:    Trigger = .{},
        ready_started:      Trigger = .{},
        round_started:      Trigger = .{},
        round_won:          Trigger = .{},
        game_over:          Trigger = .{},
        dot_eaten:          Trigger = .{},
        pill_eaten:         Trigger = .{},
        ghost_eaten:        Trigger = .{},
        pacman_eaten:       Trigger = .{},
        fruit_eaten:        Trigger = .{},
        force_leave_house:  Trigger = .{},
        fruit_active:       Trigger = .{},
    } = .{},

    audio: struct {
        voices: [NumVoices]Voice = [_]Voice{.{}} ** NumVoices,
        sounds: [NumSounds]Sound = [_]Sound{.{}} ** NumSounds,
        voice_tick_accum: i32 = 0,
        voice_tick_period: i32 = 0,
        sample_duration_ns: i32 = 0,
        sample_accum: i32 = 0,
        num_samples: u32 = 0,
        // sample_buffer is separate in UndefinedData
    } = .{},

    gfx: struct {
        // fade in/out
        fadein:  Trigger = .{},
        fadeout: Trigger = .{},
        fade: u8 = 0xFF,

        // 'hardware sprites' (meh, array default initialization sure looks awkward...)
        sprites: [NumSprites]Sprite = [_]Sprite{.{}} ** NumSprites,
        debug_markers: [NumDebugMarkers]DebugMarker = [_]DebugMarker{.{}} ** NumDebugMarkers,

        // number of valid vertices in data.vertices
        num_vertices: u32 = 0,

        // sokol-gfx objects
        pass_action: sg.PassAction = .{},
        offscreen: struct {
            vbuf:           sg.Buffer = .{},
            tile_img:       sg.Image = .{},
            palette_img:    sg.Image = .{},
            render_target:  sg.Image = .{},
            pip:            sg.Pipeline = .{},
            pass:           sg.Pass = .{},
            bind:           sg.Bindings = .{},
        } = .{},
        display: struct {
            quad_vbuf:  sg.Buffer = .{},
            pip:        sg.Pipeline = .{},
            bind:       sg.Bindings = .{},
        } = .{},
    } = .{},
};
var state: State = .{};

// keep the big undefined data out of the state struct, mixing initialized
// and uninitialized data bloats the executable size
const UndefinedData = struct {
    tile_ram:       [DisplayTilesY][DisplayTilesX]u8 = undefined,
    color_ram:      [DisplayTilesY][DisplayTilesX]u8 = undefined,
    vertices:       [MaxVertices]Vertex = undefined,
    tile_pixels:    [TileTextureHeight][TileTextureWidth]u8 = undefined,
    color_palette:  [256]u32 = undefined,
    sample_buffer:  [NumSamples]f32 = undefined,
};
var data: UndefinedData = .{};

// level specifications
const LevelSpec = struct {
    bonus_fruit: Fruit,
    bonus_score: u32,
    fright_ticks: u32,
};
const MaxLevelSpec = 21;
const LevelSpecTable = [MaxLevelSpec]LevelSpec {
    .{ .bonus_fruit=.Cherries,   .bonus_score=10,  .fright_ticks=6*60 },
    .{ .bonus_fruit=.Strawberry, .bonus_score=30,  .fright_ticks=5*60, },
    .{ .bonus_fruit=.Peach,      .bonus_score=50,  .fright_ticks=4*60, },
    .{ .bonus_fruit=.Peach,      .bonus_score=50,  .fright_ticks=3*60, },
    .{ .bonus_fruit=.Apple,      .bonus_score=70,  .fright_ticks=2*60, },
    .{ .bonus_fruit=.Apple,      .bonus_score=70,  .fright_ticks=5*60, },
    .{ .bonus_fruit=.Grapes,     .bonus_score=100, .fright_ticks=2*60, },
    .{ .bonus_fruit=.Grapes,     .bonus_score=100, .fright_ticks=2*60, },
    .{ .bonus_fruit=.Galaxian,   .bonus_score=200, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Galaxian,   .bonus_score=200, .fright_ticks=5*60, },
    .{ .bonus_fruit=.Bell,       .bonus_score=300, .fright_ticks=2*60, },
    .{ .bonus_fruit=.Bell,       .bonus_score=300, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=3*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1,    },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1*60, },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1,    },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1,    },
    .{ .bonus_fruit=.Key,        .bonus_score=500, .fright_ticks=1,    },
};

//--- helper structs and functions ---------------------------------------------

// a xorshift random number generator
fn xorshift32() u32 {
    var x = state.game.xorshift;
    x ^= x<<13;
    x ^= x>>17;
    x ^= x<<5;
    state.game.xorshift = x;
    return x;
}

// test if two ivec2 are equal
fn equal(v0: ivec2, v1: ivec2) bool {
    return (v0[0] == v1[0]) and (v0[1] == v1[1]);
}

// test if two ivec2 are nearly equal
fn nearEqual(v0: ivec2, v1: ivec2, tolerance: i16) bool {
    const d = v1 - v0;
    // use our own sloppy abs(), math.absInt() can return a runtime error
    const a: ivec2 = .{
        if (d[0] < 0) -d[0] else d[0],
        if (d[1] < 0) -d[1] else d[1]
    };
    return (a[0] <= tolerance) and (a[1] <= tolerance);
}

// squared distance between two ivec2
fn squaredDistance(v0: ivec2, v1: ivec2) i16 {
    const d = v1 - v0;
    return d[0]*d[0] + d[1]*d[1];
}

// return the pixel difference from a pixel position to the next tile midpoint
fn distToTileMid(pixel_pos: ivec2) ivec2 {
    return .{ TileWidth/2 - @mod(pixel_pos[0], TileWidth), TileHeight/2 - @mod(pixel_pos[1], TileHeight) };
}

// convert a pixel position into a tile position
fn pixelToTilePos(pixel_pos: ivec2) ivec2 {
    return .{ @divTrunc(pixel_pos[0], TileWidth), @divTrunc(pixel_pos[1], TileHeight) };
}

// return true if a tile position is valid (inside visible area)
fn validTilePos(tile_pos: ivec2) bool {
    return (tile_pos[0] >= 0) and (tile_pos[0] < DisplayTilesX) and (tile_pos[1] >= 0) and (tile_pos[1] < DisplayTilesY);
}

// return tile pos clamped to playfield borders
fn clampedTilePos(tile_pos: ivec2) ivec2 {
    return .{
        math.clamp(tile_pos[0], 0, DisplayTilesX-1),
        math.clamp(tile_pos[1], 3, DisplayTilesY-3)
    };
}

// set time trigger to next tick
fn start(t: *Trigger) void {
    t.tick = state.timing.tick + 1;
}

// set time trigger to a future tick
fn startAfter(t: *Trigger, ticks: u32) void {
    t.tick = state.timing.tick + ticks;
}

// disable a trigger
fn disable(t: *Trigger) void {
    t.tick = Trigger.DisabledTicks;
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
        return Trigger.DisabledTicks;
    }
}

// check if a time trigger is between begin and end tick
fn between(t: Trigger, begin: u32, end: u32) bool {
    assert(begin < end);
    if (t.tick != Trigger.DisabledTicks) {
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
fn after(t: Trigger, ticks: u32) bool {
    const s = since(t);
    if (s != Trigger.DisabledTicks) {
        return s >= ticks;
    }
    else {
        return false;
    }
}

// same as between(t, 0, ticks)
fn before(t: Trigger, ticks: u32) bool {
    const s = since(t);
    if (s != Trigger.DisabledTicks) {
        return s < ticks;
    }
    else {
        return false;
    }
}

// enable/disable input 
fn inputEnable() void {
    state.input.enabled = true;
}

fn inputDisable() void {
    state.input = .{};
}

// get current input state as movement direction
fn inputDir(default_dir: Dir) Dir {
    if (state.input.enabled) {
        if (state.input.up)         { return .Up; }
        else if (state.input.down)  { return .Down; }
        else if (state.input.left)  { return .Left; }
        else if (state.input.right) { return .Right; }
    }
    return default_dir;
}

// return opposite direction
fn reverseDir(dir: Dir) Dir {
    return switch (dir) {
        .Right => .Left,
        .Down  => .Up,
        .Left  => .Right,
        .Up    => .Down,
    };
}

// return a vector for a given direction
fn dirToVec(dir: Dir) ivec2 {
    return switch (dir) {
        .Right => .{  1,  0 },
        .Down  => .{  0,  1 },
        .Left  => .{ -1,  0 },
        .Up    => .{  0, -1 }
    };
}

// return the tile code for a fruit
fn fruitTileCode(fruit: Fruit) u8 {
    return switch (fruit) {
        .None       => TileCodeSpace,
        .Cherries   => TileCodeCherries,
        .Strawberry => TileCodeStrawberry,
        .Peach      => TileCodePeach,
        .Apple      => TileCodeApple,
        .Grapes     => TileCodeGrapes,
        .Galaxian   => TileCodeGalaxian,
        .Bell       => TileCodeBell,
        .Key        => TileCodeKey,
    };
}

// return the color code for a fruit
fn fruitColorCode(fruit: Fruit) u8 {
    return switch (fruit) {
        .None       => ColorCodeBlank,
        .Cherries   => ColorCodeCherries,
        .Strawberry => ColorCodeStrawberry,
        .Peach      => ColorCodePeach,
        .Apple      => ColorCodeApple,
        .Grapes     => ColorCodeGrapes,
        .Galaxian   => ColorCodeGalaxian,
        .Bell       => ColorCodeBell,
        .Key        => ColorCodeKey,
    };
}

// return the sprite tile code for a fruit
fn fruitSpriteCode(fruit: Fruit) u8 {
    return switch (fruit) {
        .None       => SpriteCodeInvisible,
        .Cherries   => SpriteCodeCherries,
        .Strawberry => SpriteCodeStrawberry,
        .Peach      => SpriteCodePeach,
        .Apple      => SpriteCodeApple,
        .Grapes     => SpriteCodeGrapes,
        .Galaxian   => SpriteCodeGalaxian,
        .Bell       => SpriteCodeBell,
        .Key        => SpriteCodeKey,
    };
}

// convert an actor pos (origin at center) to a sprite pos (origin at topleft)
fn actorToSpritePos(actorPos: ivec2) ivec2 {
    return .{ actorPos[0] - SpriteWidth/2, actorPos[1] - SpriteHeight/2 };
}

// get pointer to ghost by type
fn ghostPtr(t: GhostType) *Ghost {
    return &state.game.ghosts[@enumToInt(t)];
}

// shortcut: get pointers to ghosts by name
fn blinky() *Ghost {
    return ghostPtr(.Blinky);
}

fn pinky() *Ghost {
    return ghostPtr(.Pinky);
}

fn inky() *Ghost {
    return ghostPtr(.Inky);
}

fn clyde() *Ghost {
    return ghostPtr(.Clyde);
}

// target position (pixels) when heading back to ghost house
// (same as startingPos except Blinky's)
fn ghostHouseTargetPos(t: GhostType) ivec2 {
    return switch (t) {
        .Blinky => .{ 14*8, 17*8 + 4 },
        .Pinky  => .{ 14*8, 17*8 + 4 },
        .Inky   => .{ 12*8, 17*8 + 4 },
        .Clyde  => .{ 16*8, 17*8 + 4 },
    };
}

// ghost scatter target positions in tile coords
fn scatterTargetPos(t: GhostType) ivec2 {
    return switch (t) {
        .Blinky => .{ 25,  0 }, 
        .Pinky  => .{  2,  0 },
        .Inky   => .{ 27, 34 }, 
        .Clyde  => .{  0, 34 },
    };
}

// get level spec for the current game round
fn levelSpec(round: u32) LevelSpec {
    var i = round;
    if (i >= MaxLevelSpec) {
        i = MaxLevelSpec - 1;
    }
    return LevelSpecTable[i];
}

// check if a tile position is blocking (wall or ghost house door)
fn isBlockingTile(tile_pos: ivec2) bool {
    return gfxTileAt(tile_pos) >= 0xC0;
}

// check if a tile position contaisn a dot
fn isDot(tile_pos: ivec2) bool {
    return gfxTileAt(tile_pos) == TileCodeDot;
}

// check if a tile position contains an energizer pill
fn isPill(tile_pos: ivec2) bool {
    return gfxTileAt(tile_pos) == TileCodePill;
}

// check if a tile position is inside the teleport tunnel
fn isTunnel(tile_pos: ivec2) bool {
    return (tile_pos[1] == 17) and ((tile_pos[0] <= 5) or (tile_pos[0] >= 22));
}

// check if a tile position is inside one of the two "red zones" where 
// ghost are not allowed to move upward
fn isRedZone(tile_pos: ivec2) bool {
    return (tile_pos[0] >= 11) and (tile_pos[0] <= 16) and ((tile_pos[1] ==14) or (tile_pos[1] == 26));
}

// test if movement from a pixel position to a wanted position is possible,
// allow_cornering is Pacman's feature to take a diagonal shortcut around corners
fn canMove(pixel_pos: ivec2, wanted_dir: Dir, allow_cornering: bool) bool {
    const dist_mid = distToTileMid(pixel_pos);
    const dir_vec = dirToVec(wanted_dir);

    // distance to midpoint in move direction and perpendicular direction
    const move_dist_mid = if (dir_vec[1] != 0) dist_mid[1] else dist_mid[0];
    const perp_dist_mid = if (dir_vec[1] != 0) dist_mid[0] else dist_mid[1];

    // look one tile ahead in movement direction
    const tile_pos = pixelToTilePos(pixel_pos);
    const check_pos = clampedTilePos(tile_pos + dir_vec);
    const is_blocked = isBlockingTile(check_pos);
    if ((!allow_cornering and (0 != perp_dist_mid)) or (is_blocked and (0 == move_dist_mid))) {
        // way is blocked
        return false;
    }
    else {
        // way is free
        return true;
    }
}

// compute a new pixel position along a direction (without blocking check)
fn move(pixel_pos: ivec2, dir: Dir, allow_cornering: bool) ivec2 {
    const dir_vec = dirToVec(dir);
    var pos = pixel_pos + dir_vec;

    // if cornering allowed, drag the position towards the center-line
    if (allow_cornering) {
        const dist_mid = distToTileMid(pos);
        if (dir_vec[0] != 0) {
            if (dist_mid[1] < 0)        { pos[1] -= 1; }
            else if (dist_mid[1] > 0)   { pos[1] += 1; }
        }
        else if (dir_vec[1] != 0) {
            if (dist_mid[0] < 0)        { pos[0] -= 1; }
            else if (dist_mid[0] > 0)   { pos[0] += 1; }
        }
    }

    // wrap x position around (only possible inside teleport tunnel)
    if (pos[0] < 0) {
        pos[0] = DisplayPixelsX - 1;
    }
    else if (pos[0] >= DisplayPixelsX) {
        pos[0] = 0;
    }
    return pos;
}

// shortcuts to get sprite pointers by name
fn spritePacman() *Sprite {
    return &state.gfx.sprites[0];
}
fn spriteGhost(ghost_type: GhostType) *Sprite {
    return &state.gfx.sprites[@enumToInt(ghost_type) + 1];
}
fn spriteBlinky() *Sprite {
    return &state.gfx.sprites[1];
}
fn spritePinky() *Sprite {
    return &state.gfx.sprites[2];
}
fn spriteInky() *Sprite {
    return &state.gfx.sprites[3];
}
fn spriteClyde() *Sprite {
    return &state.gfx.sprites[4];
}
fn spriteFruit() *Sprite {
    return &state.gfx.sprites[5];
}

// set sprite image to animated pacman
fn spriteImagePacman(dir: Dir, tick: u32) void {
    const tiles = [2][4]u8 {
        [_]u8 { 44, 46, 48, 46 }, // horizontal (needs flipx)
        [_]u8 { 45, 47, 48, 47 }  // vertical (needs flipy)
    };
    const phase = (tick / 4) & 3;
    var spr = spritePacman();
    spr.enabled = true;
    spr.tile = tiles[@enumToInt(dir) & 1][phase];
    spr.color = ColorCodePacman;
    spr.flipx = (dir == .Left);
    spr.flipy = (dir == .Up);
}

// set sprite image to Pacman death sequence
fn spriteImagePacmanDeath(tick: u32) void {
    // the death animation tile sequence starts at sprite tile number 52 and ends at 63
    const tile: u32 = math.clamp(52 + (tick / 8), 0, 63);
    var spr = spritePacman();
    spr.tile = @intCast(u8, tile);
    spr.flipx = false;
    spr.flipy = false;
}

// set sprite image to animated ghost
fn spriteImageGhost(ghost_type: GhostType, dir: Dir, tick: u32) void {
    const tiles = [4][2]u8 {
        [_]u8 { 32, 33 },   // right
        [_]u8 { 34, 35 },   // down
        [_]u8 { 36, 37 },   // left
        [_]u8 { 38, 39 },   // up
    };
    const phase = (tick / 8) & 1;
    var spr = spriteGhost(ghost_type);
    spr.tile = tiles[@enumToInt(dir)][phase];
    spr.color = ColorCodeBlinky + @enumToInt(ghost_type)*2;
}

// set sprite image to frightened ghost
fn spriteImageGhostFrightened(ghost_type: GhostType, tick: u32, blinking_tick: u32) void {
    const tiles = [2]u8 { 28, 29 };
    const phase = (tick / 4) & 1;
    var spr = spriteGhost(ghost_type);
    spr.tile = tiles[phase];
    if (tick > blinking_tick) {
        // towards end of frightened period, start blinking
        spr.color = if (0 != (tick & 0x10)) ColorCodeFrightened else ColorCodeFrightenedBlinking;
    }
    else {
        spr.color = ColorCodeFrightened;
    }
}

// set sprite to ghost eyes, these are the normal ghost sprite
// images but with a different color code which makes
// only the eyes visible
fn spriteImageGhostEyes(ghost_type: GhostType, dir: Dir) void {
    const tiles = [4]u8 { 32, 34, 36, 38 };
    var spr = spriteGhost(ghost_type);
    spr.tile = tiles[@enumToInt(dir)];
    spr.color = ColorCodeEyes;
}

//--- gameplay system ----------------------------------------------------------

// the central game tick function, called at 60Hz
fn gameTick() void {

    // initialize game-state once
    if (now(state.game.started)) {
        // debug: skip predule
        const prelude_ticks_per_sec = if (DbgSkipPrelude) 1 else 60;
        start(&state.gfx.fadein);
        start(&state.game.prelude_started);
        startAfter(&state.game.ready_started, 2*prelude_ticks_per_sec);
        soundPrelude();
        gameInit();
    }

    // initialize new round (after eating all dots or losing a life)
    if (now(state.game.ready_started)) {
        gameRoundInit();
        // after 2 seconds, start the interactive game loop
        startAfter(&state.game.round_started, 2*60 + 10);
    }
    if (now(state.game.round_started)) {
        state.game.freeze &= ~FreezeReady;
        // clear the READY! message
        gfxColorText(.{11,20}, ColorCodeDot, "      ");
        soundWeeooh();
    }

    // activate/deactivate bonus fruit
    if (now(state.game.fruit_active)) {
        state.game.active_fruit = levelSpec(state.game.round).bonus_fruit;
    }
    else if (afterOnce(state.game.fruit_active, FruitActiveTicks)) {
        state.game.active_fruit = .None;
    }

    // stop frightened sound and start weeooh sound
    if (afterOnce(state.game.pill_eaten, levelSpec(state.game.round).fright_ticks)) {
        soundWeeooh();
    }

    // if game is frozen because Pacman ate a ghost, unfreeze after a while
    if (0 != (state.game.freeze & FreezeEatGhost)) {
        if (afterOnce(state.game.ghost_eaten, GhostEatenFreezeTicks)) {
            state.game.freeze &= ~FreezeEatGhost;
        }
    }

    // play pacman-death sound
    if (afterOnce(state.game.pacman_eaten, PacmanEatenTicks)) {
        soundDead();
    }

    // update Pacman and ghost state
    if (0 == state.game.freeze) {
        gameUpdateActors();
    }
    // update the dynamic background tiles and sprite images
    gameUpdateTiles();
    gameUpdateSprites();

    // update hiscore if broken
    if (state.game.score > state.game.hiscore) {
        state.game.hiscore = state.game.score;
    }

    // check for end-round condition
    if (now(state.game.round_won)) {
        state.game.freeze |= FreezeWon;
        startAfter(&state.game.ready_started, RoundWonTicks);
    }
    if (now(state.game.game_over)) {
        gfxColorText(.{9,20}, 1, "GAME  OVER");
        inputDisable();
        startAfter(&state.gfx.fadeout, GameOverTicks);
        startAfter(&state.intro.started, GameOverTicks + FadeTicks);
    }

    if (DbgEscape) {
        if (state.input.esc) {
            inputDisable();
            start(&state.gfx.fadeout);
            startAfter(&state.intro.started, FadeTicks);
        }
    }

    // render debug markers (current ghost targets)
    if (DbgShowMarkers) {
        for (state.game.ghosts) |*ghost, i| {
            const tile: u8 = switch (ghost.state) {
                .None => 'N',
                .Chase => 'C',
                .Scatter => 'S',
                .Frightened => 'F',
                .Eyes => 'E',
                .House => 'H',
                .LeaveHouse => 'L',
                .EnterHouse => 'E',
            };
            state.gfx.debug_markers[i] = .{
                .enabled = true,
                .tile = tile,
                .color = @intCast(u8, ColorCodeBlinky + 2*i),
                .tile_pos = clampedTilePos(ghost.target_pos)
            };
        }
    }
}

// the central Pacman- and ghost-behaviour function, called once per game tick
fn gameUpdateActors() void {
    // Pacman "AI"
    if (gamePacmanShouldMove()) {
        var actor = &state.game.pacman.actor;
        const wanted_dir = inputDir(actor.dir);
        const allow_cornering = true;
        // look ahead to check if wanted direction is blocked
        if (canMove(actor.pos, wanted_dir, allow_cornering)) {
            actor.dir = wanted_dir;
        }
        // move into the selected direction
        if (canMove(actor.pos, actor.dir, allow_cornering)) {
            actor.pos = move(actor.pos, actor.dir, allow_cornering);
            actor.anim_tick += 1;
        }
        // eat dot or energizer pill?
        const pacman_tile_pos = pixelToTilePos(actor.pos);
        if (isDot(pacman_tile_pos)) {
            gfxTile(pacman_tile_pos, TileCodeSpace);
            state.game.score += 1;
            start(&state.game.dot_eaten);
            start(&state.game.force_leave_house);
            gameUpdateDotsEaten();
            gameUpdateGhostHouseDotCounters();
        }
        if (isPill(pacman_tile_pos)) {
            gfxTile(pacman_tile_pos, TileCodeSpace);
            state.game.score += 5;
            start(&state.game.pill_eaten);
            state.game.num_ghosts_eaten = 0;
            for (state.game.ghosts) |*ghost| {
                start(&ghost.frightened);
            }
            gameUpdateDotsEaten();
            soundFrightened();
        }
        // check if Pacman eats the bonus fruit
        if (state.game.active_fruit != .None) {
            const test_pos = pixelToTilePos(actor.pos + ivec2{TileWidth/2,0});
            if (equal(test_pos, .{14,20})) {
                start(&state.game.fruit_eaten);
                state.game.score += levelSpec(state.game.round).bonus_score;
                gfxFruitScore(state.game.active_fruit);
                state.game.active_fruit = .None;
                soundEatFruit();
            }
        }
        // check if Pacman collides with a ghost
        for (state.game.ghosts) |*ghost| {
            const ghost_tile_pos = pixelToTilePos(ghost.actor.pos);
            if (equal(ghost_tile_pos, pacman_tile_pos)) {
                switch (ghost.state) {
                    .Frightened => {
                        // Pacman eats ghost
                        ghost.state = .Eyes;
                        start(&ghost.eaten);
                        start(&state.game.ghost_eaten);
                        state.game.num_ghosts_eaten += 1;
                        // increase score by 20, 40, 80, 160
                        // FIXME Zig: "10 * (1 << state.game.num_ghosts_eaten)" is quite awkward in Zig
                        state.game.score += 10 * math.pow(u32, 2, state.game.num_ghosts_eaten);
                        state.game.freeze |= FreezeEatGhost;
                        soundEatGhost();
                    },
                    .Chase, .Scatter => {
                        // ghost eats Pacman
                        if (!DbgGodMode) {
                            soundClear();
                            start(&state.game.pacman_eaten);
                            state.game.freeze |= FreezeDead;
                            // if Pacman has any lives left, start a new round, otherwise start the game over sequence
                            if (state.game.num_lives > 0) {
                                startAfter(&state.game.ready_started, PacmanEatenTicks + PacmanDeathTicks);
                            }
                            else {
                                startAfter(&state.game.game_over, PacmanEatenTicks + PacmanDeathTicks);
                            }
                        }
                    },
                    else => {}
                }
            }
        }
    }

    // ghost AIs
    for (state.game.ghosts) |*ghost| {
        // handle ghost state transitions
        gameUpdateGhostState(ghost);
        // update the ghosts target position
        gameUpdateGhostTarget(ghost);
        // finally, move the ghost towards its target position
        const num_move_ticks = gameGhostSpeed(ghost);
        var i: u32 = 0;
        while (i < num_move_ticks): (i += 1) {
            const force_move = gameUpdateGhostDir(ghost);
            const allow_cornering = false;
            if (force_move or canMove(ghost.actor.pos, ghost.actor.dir, allow_cornering)) {
                ghost.actor.pos = move(ghost.actor.pos, ghost.actor.dir, allow_cornering);
                ghost.actor.anim_tick += 1;
            }
        }
    }
}

// this function takes care of switching ghosts into a new state, this is one
// of two important functions of the ghost AI (the other being the target selection
// function below)
fn gameUpdateGhostState(ghost: *Ghost) void {
    var new_state = ghost.state;
    switch (ghost.state) {
        .Eyes => {
            // When in eye state (heading back to the ghost house), check if the
            // target position in front of the ghost house has been reached, then
            // switch into ENTERHOUSE state. Since ghosts in eye state move faster
            // than one pixel per tick, do a fuzzy comparison with the target pos
            if (nearEqual(ghost.actor.pos, .{ AntePortasX, AntePortasY}, 1)) {
                new_state = .EnterHouse;
            }
        },
        .EnterHouse => {
            // Ghosts that enter the ghost house during the gameplay loop immediately
            // leave the house again after reaching their target position inside the house.
            if (nearEqual(ghost.actor.pos, ghostHouseTargetPos(ghost.type), 1)) {
                new_state = .LeaveHouse;
            }
        },
        .House => {
            // Ghosts only remain in the "house state" after a new game round 
            // has been started. The conditions when ghosts leave the house
            // are a bit complicated, best to check the Pacman Dossier for the details. 
            if (afterOnce(state.game.force_leave_house, 4*60)) {
                // if Pacman hasn't eaten dots for 4 seconds, the next ghost
                // is forced out of the house
                // FIXME: time is reduced to 3 seconds after round 5
                new_state = .LeaveHouse;
                start(&state.game.force_leave_house);
            }
            else if (state.game.global_dot_counter_active) {
                // if Pacman has lost a life this round, the global dot counter is used
                const dot_counter_limit: u32 = switch (ghost.type) {
                    .Blinky => 0,
                    .Pinky => 7,
                    .Inky => 17,
                    .Clyde => 32,
                };
                if (state.game.global_dot_counter == dot_counter_limit) {
                    new_state = .LeaveHouse;
                    // NOTE that global dot counter is deactivated if (and only if) Clyde
                    // is in the house and the dot counter reaches 32
                    if (ghost.type == .Clyde) {
                        state.game.global_dot_counter_active = false;
                    }
                }
            }
            else if (ghost.dot_counter == ghost.dot_limit) {
                // in the normal case, check the ghost's personal dot counter
                new_state = .LeaveHouse;
            }
        },
        .LeaveHouse => {
            // ghosts immediately switch to scatter mode after leaving the ghost house
            if (ghost.actor.pos[1] == AntePortasY) {
                new_state = .Scatter;
            }
        },
        else => {
            // all other states: switch between frightened, scatter and chase states
            if (before(ghost.frightened, levelSpec(state.game.round).fright_ticks)) {
                new_state = .Frightened;
            }
            else {
                const t = since(state.game.round_started);
                if (t < 7*60)       { new_state = .Scatter; }
                else if (t < 27*60) { new_state = .Chase; }
                else if (t < 34*60) { new_state = .Scatter; }
                else if (t < 54*60) { new_state = .Chase; }
                else if (t < 59*60) { new_state = .Scatter; }
                else if (t < 79*60) { new_state = .Chase; }
                else if (t < 84*60) { new_state = .Scatter; }
                else                { new_state = .Chase; }
            }
        }
    }

    // handle state transitions
    if (new_state != ghost.state) {
        switch (ghost.state) {
            .LeaveHouse => {
                // after leaving the house, head to the left
                ghost.next_dir = .Left;
                ghost.actor.dir = .Left;
            },
            .EnterHouse => {
                // a ghost that was eaten is immune to frighten until Pacman eats another pill
                disable(&ghost.frightened);
            },
            .Frightened => {
                // don't reverse direction when leaving frightened state
            },
            .Scatter, .Chase => {
                // any transition from scatter and chase mode causes a reversal of direction
                ghost.next_dir = reverseDir(ghost.actor.dir);
            },
            else => {}
        }
        ghost.state = new_state;
    }
}

// update the ghost's target position, this is the other important function
// of the ghost's AI
fn gameUpdateGhostTarget(ghost: *Ghost) void {
    switch (ghost.state) {
        .Scatter => {
            // when in scatter mode, each ghost heads to its own scatter
            // target position in the playfield corners
            ghost.target_pos = scatterTargetPos(ghost.type);
        },
        .Chase => {
            // when in chase mode, each ghost has its own particular
            // chase behaviour (see the Pacman Dossier for details)
            const pm = &state.game.pacman.actor;
            const pm_pos = pixelToTilePos(pm.pos);
            const pm_dir = dirToVec(pm.dir);
            switch (ghost.type) {
                .Blinky => {
                    // Blinky directly chases Pacman
                    ghost.target_pos = pm_pos;
                },
                .Pinky => {
                    // Pinky target is 4 tiles ahead of Pacman
                    // FIXME: does not reproduce 'diagonal overflow'
                    ghost.target_pos = pm_pos + pm_dir * ivec2{4,4};
                },
                .Inky => {
                    // Inky targets an extrapolated pos along a line two tiles
                    // ahead of Pacman through Blinky
                    const blinky_pos = pixelToTilePos(blinky().actor.pos);
                    const d = (pm_pos + pm_dir * ivec2{2,2}) - blinky_pos;
                    ghost.target_pos = blinky_pos + d * ivec2{2,2};
                },
                .Clyde => {
                    // if Clyde is far away from Pacman, he chases Pacman, 
                    // but if close he moves towards the scatter target
                    if (squaredDistance(pixelToTilePos(ghost.actor.pos), pm_pos) > 64) {
                        ghost.target_pos = pm_pos;
                    }
                    else {
                        ghost.target_pos = scatterTargetPos(.Clyde);
                    }
                }
            }
        },
        .Frightened => {
            // in frightened state just select a random target position
            // this has the effect that ghosts in frightened state 
            // move in a random direction at each intersection
            ghost.target_pos = .{
                @intCast(i16, xorshift32() % DisplayTilesX),
                @intCast(i16, xorshift32() % DisplayTilesY)
            };
        },
        .Eyes => {
            // move towards the ghost house door
            ghost.target_pos = .{ 13, 14 };
        },
        else => {}
    }
}

// compute the next ghost direction, return true if resulting movement
// should always happen regardless of current ghost position or blocking
// tiles (this special case is used for movement inside the ghost house)
fn gameUpdateGhostDir(ghost: *Ghost) bool {
    switch (ghost.state) {
        .House => {
            // inside ghost house, just move up and down
            if (ghost.actor.pos[1] <= 17*TileHeight) {
                ghost.next_dir = .Down;
            }
            else if (ghost.actor.pos[1] >= 18*TileHeight) {
                ghost.next_dir = .Up;
            }
            ghost.actor.dir = ghost.next_dir;
            // force movement
            return true;
        },
        .LeaveHouse => {
            // navigate ghost out of the ghost house
            const pos = ghost.actor.pos;
            if (pos[0] == AntePortasX) {
                if (pos[1] > AntePortasY) {
                    ghost.next_dir = .Up;
                }
            }
            else {
                const mid_y: i16 = 17*TileHeight + TileHeight/2;
                if (pos[1] > mid_y) {
                    ghost.next_dir = .Up;
                }
                else if (pos[1] < mid_y) {
                    ghost.next_dir = .Down;
                }
                else {
                    ghost.next_dir = if (pos[0] > AntePortasX) .Left else .Right;
                }
            }
            ghost.actor.dir = ghost.next_dir;
            // force movement
            return true;
        },
        .EnterHouse => {
            // navigate towards the ghost house target pos
            const pos = ghost.actor.pos;
            const tile_pos = pixelToTilePos(pos);
            const tgt_pos = ghostHouseTargetPos(ghost.type);
            if (tile_pos[1] == 14) {
                if (pos[0] != AntePortasX) {
                    ghost.next_dir = if (pos[0] > AntePortasX) .Left else .Right;
                }
                else {
                    ghost.next_dir = .Down;
                }
            }
            else if (pos[1] == tgt_pos[1]) {
                ghost.next_dir = if (pos[0] > tgt_pos[0]) .Left else .Right;
            }
            ghost.actor.dir = ghost.next_dir;
            // force movement
            return true;            
        },
        else => {
            // scatter/chase/frightened: just head towards the current target point
            const dist_to_mid = distToTileMid(ghost.actor.pos);
            if ((dist_to_mid[0] == 0) and (dist_to_mid[1] == 0)) {
                // new direction is the previously computed next direction
                ghost.actor.dir = ghost.next_dir;

                // compute new next-direction
                const dir_vec = dirToVec(ghost.actor.dir);
                const lookahead_pos = pixelToTilePos(ghost.actor.pos) + dir_vec;

                // try each direction and take the one that's closest to the target pos
                const dirs = [_]Dir { .Up, .Left, .Down, .Right };
                var min_dist: i16 = 32000;
                for (dirs) |dir| {
                    // if ghost is in one of the two 'red zones', forbid upward movement
                    // (see Pacman Dossier "Areas To Exploit")
                    if (isRedZone(lookahead_pos) and (dir == .Up) and (ghost.state != .Eyes)) {
                        continue;
                    }
                    const test_pos = clampedTilePos(lookahead_pos + dirToVec(dir));
                    if ((reverseDir(dir) != ghost.actor.dir) and !isBlockingTile(test_pos)) {
                        const cur_dist = squaredDistance(test_pos, ghost.target_pos);
                        if (cur_dist < min_dist) {
                            min_dist = cur_dist;
                            ghost.next_dir = dir;
                        }
                    }
                }
            }
            // moving with blocking-check
            return false;
        }
    }
}

// Return true if Pacman should move in current game tick. When eating dots,
// Pacman is slightly slower then ghosts, otherwise slightly faster
fn gamePacmanShouldMove() bool {
    if (now(state.game.dot_eaten)) {
        // eating a dot causes Pacman to stop for 1 tick
        return false;
    }
    else if (since(state.game.pill_eaten) < 3) {
        // eating an energizer pill causes Pacman to stop for 3 ticks
        return false;
    }
    else {
        return 0 != (state.timing.tick % 8);
    }
}

// return number of pixels a ghost should move this tick, this can't be a simple
// move/don't move boolean return value, because ghosts in eye state move faster
// than one pixel per tick
fn gameGhostSpeed(ghost: *const Ghost) u32 {
    switch (ghost.state) {
        .House, .LeaveHouse, .Frightened => {
            // inside house and when frightened at half speed
            return state.timing.tick & 1;
        },
        .Eyes, .EnterHouse => {
            // estimated 1.5x when in eye state, Pacman Dossier is silent on this
            return if (0 != (state.timing.tick & 1)) 1 else 2;
        },
        else => {
            if (isTunnel(pixelToTilePos(ghost.actor.pos))) {
                // move drastically slower when inside tunnel
                return if (0 != ((state.timing.tick * 2) % 4)) 1 else 0;
            }
            else {
                // otherwise move just a bit slower than Pacman
                return if (0 != state.timing.tick % 7) 1 else 0;
            }
        }
    }
}

// called when a dot or pill has been eaten, checks if a round has been won
// (all dots and pills eaten), whether to show the bonus fruit, and finally
// plays the dot-eaten sound effect
fn gameUpdateDotsEaten() void {
    state.game.num_dots_eaten += 1;
    switch (state.game.num_dots_eaten) {
        NumDots => {
            // all dots eaten, round won
            start(&state.game.round_won);
            soundClear();
        },
        70, 170 => {
            // at 70 and 170 dots, show the bonus fruit
            start(&state.game.fruit_active);
        },
        else => {}
    }
    soundEatDot(state.game.num_dots_eaten);
}

// Update the dot counters used to decide whether ghosts must leave the house.
// 
// This is called each time Pacman eats a dot.
// 
// Each ghost has a dot limit which is reset at the start of a round. Each time
// Pacman eats a dot, the highest priority ghost in the ghost house counts
// down its dot counter.
// 
// When the ghost's dot counter reaches zero the ghost leaves the house
// and the next highest-priority dot counter starts counting.
// 
// If a life is lost, the personal dot counters are deactivated and instead
// a global dot counter is used.
// 
// If pacman doesn't eat dots for a while, the next ghost is forced out of the
// house using a timer.
// 
fn gameUpdateGhostHouseDotCounters() void {
    // if the new round was started because Pacman lost a life, use the global
    // dot counter (this mode will be deactivated again after all ghosts left the
    // house)
    if (state.game.global_dot_counter_active) {
        state.game.global_dot_counter += 1;
    }
    else {
        // otherwise each ghost has his own personal dot counter to decide
        // when to leave the ghost house, the dot counter is only increments
        // for the first ghost below the dot limit
        for (state.game.ghosts) |*ghost| {
            if (ghost.dot_counter < ghost.dot_limit) {
                ghost.dot_counter += 1;
                break;
            }
        }
    }
}

// common time trigger initialization at start of a game round
fn gameInitTriggers() void {
    disable(&state.game.round_won);
    disable(&state.game.game_over);
    disable(&state.game.dot_eaten);
    disable(&state.game.pill_eaten);
    disable(&state.game.ghost_eaten);
    disable(&state.game.pacman_eaten);
    disable(&state.game.fruit_eaten);
    disable(&state.game.force_leave_house);
    disable(&state.game.fruit_active);
}

// intialize a new game
fn gameInit() void {
    inputEnable();
    gameInitTriggers();
    state.game.round = DbgStartRound;
    state.game.freeze = FreezePrelude;
    state.game.num_lives = NumLives;
    state.game.global_dot_counter_active = false;
    state.game.global_dot_counter = 0;
    state.game.num_dots_eaten = 0;
    state.game.score = 0;

    // draw the playfield and PLAYER ONE READY! message
    gfxClear(TileCodeSpace, ColorCodeDot);
    gfxColorText(.{9,0}, ColorCodeDefault, "HIGH SCORE");
    gameInitPlayfield();
    gfxColorText(.{9,14}, 5, "PLAYER ONE");
    gfxColorText(.{11,20}, 9, "READY!");
}

// initialize the playfield background tiles
fn gameInitPlayfield() void {
    gfxClearPlayfieldToColor(ColorCodeDot);
    // decode the playfield data from an ASCII map
    const tiles =
       \\0UUUUUUUUUUUU45UUUUUUUUUUUU1
       \\L............rl............R
       \\L.ebbf.ebbbf.rl.ebbbf.ebbf.R
       \\LPr  l.r   l.rl.r   l.r  lPR
       \\L.guuh.guuuh.gh.guuuh.guuh.R
       \\L..........................R
       \\L.ebbf.ef.ebbbbbbf.ef.ebbf.R
       \\L.guuh.rl.guuyxuuh.rl.guuh.R
       \\L......rl....rl....rl......R
       \\2BBBBf.rzbbf rl ebbwl.eBBBB3
       \\     L.rxuuh gh guuyl.R     
       \\     L.rl          rl.R     
       \\     L.rl mjs--tjn rl.R     
       \\UUUUUh.gh i      q gh.gUUUUU
       \\      .   i      q   .      
       \\BBBBBf.ef i      q ef.eBBBBB
       \\     L.rl okkkkkkp rl.R     
       \\     L.rl          rl.R     
       \\     L.rl ebbbbbbf rl.R     
       \\0UUUUh.gh guuyxuuh gh.gUUUU1
       \\L............rl............R
       \\L.ebbf.ebbbf.rl.ebbbf.ebbf.R
       \\L.guyl.guuuh.gh.guuuh.rxuh.R
       \\LP..rl.......  .......rl..PR
       \\6bf.rl.ef.ebbbbbbf.ef.rl.eb8
       \\7uh.gh.rl.guuyxuuh.rl.gh.gu9
       \\L......rl....rl....rl......R
       \\L.ebbbbwzbbf.rl.ebbwzbbbbf.R
       \\L.guuuuuuuuh.gh.guuuuuuuuh.R
       \\L..........................R
       \\2BBBBBBBBBBBBBBBBBBBBBBBBBB3
       ;
    // map ASCII to tile codes
    var t = [_]u8{TileCodeDot} ** 128;
    t[' ']=0x40; t['0']=0xD1; t['1']=0xD0; t['2']=0xD5; t['3']=0xD4; t['4']=0xFB;
    t['5']=0xFA; t['6']=0xD7; t['7']=0xD9; t['8']=0xD6; t['9']=0xD8; t['U']=0xDB;
    t['L']=0xD3; t['R']=0xD2; t['B']=0xDC; t['b']=0xDF; t['e']=0xE7; t['f']=0xE6;
    t['g']=0xEB; t['h']=0xEA; t['l']=0xE8; t['r']=0xE9; t['u']=0xE5; t['w']=0xF5;
    t['x']=0xF2; t['y']=0xF3; t['z']=0xF4; t['m']=0xED; t['n']=0xEC; t['o']=0xEF;
    t['p']=0xEE; t['j']=0xDD; t['i']=0xD2; t['k']=0xDB; t['q']=0xD3; t['s']=0xF1;
    t['t']=0xF0; t['-']=TileCodeDoor; t['P']=TileCodePill;
    var y: i16 = 3;
    var i: usize = 0;
    while (y < DisplayTilesY-2): (y += 1) {
        var x: i16 = 0;
        while (x < DisplayTilesX): ({ x += 1; i += 1; }) {
            gfxTile(.{x,y}, t[tiles[i] & 127]);
        }
        // skip newline
        if (tiles[i] == '\r') {
            i += 1;
        }
        if (tiles[i] == '\n') {
            i += 1;
        }
    }

    // ghost house door color
    gfxColor(.{13,15}, 0x18);
    gfxColor(.{14,15}, 0x18);
}

// initialize a new game round
fn gameRoundInit() void {
    gfxClearSprites();

    // clear the PLAYER ONE text
    gfxColorText(.{9,14}, ColorCodeDot, "          ");

    // if a new round was started because Pacman had won (eaten all dots),
    // redraw the playfield and reset the global dot counter
    if (state.game.num_dots_eaten == NumDots) {
        state.game.round += 1;
        state.game.num_dots_eaten = 0;
        state.game.global_dot_counter_active = false;
        gameInitPlayfield();
    }
    else {
        // if the previous round was lost, use the global dot counter 
        // to detect when ghosts should leave the ghost house instead
        // of the per-ghost dot counter
        if (state.game.num_lives != NumLives) {
            state.game.global_dot_counter_active = true;
            state.game.global_dot_counter = 0;
        }
        state.game.num_lives -= 1;
    }
    assert(state.game.num_lives >= 0);

    state.game.active_fruit = .None;
    state.game.freeze = FreezeReady;
    state.game.xorshift = 0x12345678;
    state.game.num_ghosts_eaten = 0;
    gameInitTriggers();

    gfxColorText(.{11,20}, 9, "READY!");

    // the force-house trigger forces ghosts out of the house if Pacman
    // hasn't been eating dots for a while
    start(&state.game.force_leave_house);

    // Pacman starts running to the left
    state.game.pacman = .{
        .actor = .{
            .dir = .Left,
            .pos = .{ 14*8, 26*8+4 }
        }
    };
    // Blinky starts outside the ghost house, looking to the left and in scatter mode
    blinky().* = .{
        .actor = .{
            .dir = .Left,
            .pos = .{ 14*8, 14*8 + 4 },
        },
        .type = .Blinky,
        .next_dir = .Left,
        .state = .Scatter
    };
    // Pinky starts in the middle slot of the ghost house, heading down
    pinky().* = .{
        .actor = .{
            .dir = .Down,
            .pos = .{ 14*8, 17*8 + 4 },
        },
        .type = .Pinky,
        .next_dir = .Down,
        .state = .House,
    };
    // Inky starts in the left slot of the ghost house, moving up
    inky().* = .{
        .actor = .{
            .dir = .Up,
            .pos = .{ 12*8, 17*8 + 4 },
        },
        .type = .Inky,
        .next_dir = .Up,
        .state = .House,
        .dot_limit = 30,
    };
    // Clyde starts in the righ slot of the ghost house, moving up
    clyde().* = .{
        .actor = .{
            .dir = .Up,
            .pos = .{ 16*8, 17*8 + 4 },
        },
        .type = .Clyde,
        .next_dir = .Up,
        .state = .House,
        .dot_limit = 60
    };
    
    // reset sprites
    spritePacman().* = .{ .enabled = true, .color = ColorCodePacman };
    spriteBlinky().* = .{ .enabled = true, .color = ColorCodeBlinky };
    spritePinky().*  = .{ .enabled = true, .color = ColorCodePinky  };
    spriteInky().*   = .{ .enabled = true, .color = ColorCodeInky   };
    spriteClyde().*  = .{ .enabled = true, .color = ColorCodeClyde  };
}

// update dynamic background tiles
fn gameUpdateTiles() void {
    // print score and hiscore
    gfxColorScore(.{6,1}, ColorCodeDefault, state.game.score);
    if (state.game.hiscore > 0) {
        gfxColorScore(.{16,1}, ColorCodeDefault, state.game.hiscore);
    }

    // update the energizer pill state (blinking/non-blinking)
    const pill_pos = [NumPills]ivec2 { .{1,6}, .{26,6}, .{1,26}, .{26,26} };
    for (pill_pos) |pos| {
        if (0 != state.game.freeze) {
            gfxColor(pos, ColorCodeDot);
        }
        else {
            gfxColor(pos, if (0 != (state.timing.tick & 8)) ColorCodeDot else ColorCodeBlank);
        }
    }

    // clear the fruit-eaten score after Pacman has eaten a bonus fruit
    if (afterOnce(state.game.fruit_eaten, 2*60)) {
        gfxFruitScore(.None);
    }

    // remaining lives in bottom-left corner
    {
        var i: i16 = 0;
        while (i < NumLives): (i += 1) {
            const color: u8 = if (i < state.game.num_lives) ColorCodePacman else ColorCodeBlank;
            gfxColorTileQuad(.{2+2*i,34}, color, TileCodeLife);
        }
    }

    // bonus fruits in bottom-right corner
    {
        var i: i32 = @intCast(i32,state.game.round) - 7 + 1;
        var x: i16 = 24;
        while (i <= state.game.round): (i += 1) {
            if (i >= 0) {
                const fruit = levelSpec(@intCast(u32,i)).bonus_fruit;
                gfxColorTileQuad(.{x,34}, fruitColorCode(fruit), fruitTileCode(fruit));
                x -= 2;
            }
        }
    }

    // if game round was won, render the entire playfield as blinking blue/white
    if (after(state.game.round_won, 1*60)) {
        if (0 != (since(state.game.round_won) & 0x10)) {
            gfxClearPlayfieldToColor(ColorCodeDot);
        }
        else {
            gfxClearPlayfieldToColor(ColorCodeWhiteBorder);
        }
    }
}

// update sprite images
fn gameUpdateSprites() void {
    // update Pacman sprite
    {
        var spr = spritePacman();
        if (spr.enabled) {
            const actor = &state.game.pacman.actor;
            spr.pos = actorToSpritePos(actor.pos);
            if (0 != (state.game.freeze & FreezeEatGhost)) {
                // hide Pacman shortly after he's eaten a ghost
                spr.tile = SpriteCodeInvisible;
            }
            else if (0 != (state.game.freeze & (FreezePrelude|FreezeReady))) {
                // special case game frozen at start of round, show "closed mouth" Pacman
                spr.tile = SpriteCodePacmanClosedMouth;
            }
            else if (0 != (state.game.freeze & (FreezeDead))) {
                // play the Pacman death animation after a short pause
                if (after(state.game.pacman_eaten, PacmanEatenTicks)) {
                    spriteImagePacmanDeath(since(state.game.pacman_eaten) - PacmanEatenTicks);
                }
            }
            else {
                // regular Pacman animation
                spriteImagePacman(actor.dir, actor.anim_tick);
            }
        }
    }

    // update ghost sprites
    // FIXME: Zig doesn't allow a const pointer in the loop?
    for (state.game.ghosts) |*ghost, i| {
        var spr = spriteGhost(ghost.type);
        if (spr.enabled) {
            spr.pos = actorToSpritePos(ghost.actor.pos);
            // if Pacman has just died, hide ghosts
            if (0 != (state.game.freeze & FreezeDead)) {
                if (after(state.game.pacman_eaten, PacmanEatenTicks)) {
                    spr.tile = SpriteCodeInvisible;
                }
            }
            // if Pacman has won the round, hide the ghosts
            else if (0 != (state.game.freeze & FreezeWon)) {
                spr.tile = SpriteCodeInvisible;
            }
            else switch (ghost.state) {
                .Eyes => {
                    if (before(ghost.eaten, GhostEatenFreezeTicks)) {
                        // if the ghost was *just* eaten by Pacman, the ghost's sprite
                        // is replaced with a score number for a short time
                        // (200 for the first ghost, followed by 400, 800 and 1600)
                        spr.tile = SpriteCodeScore200 + state.game.num_ghosts_eaten - 1;
                        spr.color = ColorCodeGhostScore;
                    }
                    else {
                        // afterwards the ghost's eyes are shown, heading back to the ghost house
                        spriteImageGhostEyes(ghost.type, ghost.next_dir);
                    }
                },
                .EnterHouse => {
                    // show ghost eyes while entering the ghost house
                    spriteImageGhostEyes(ghost.type, ghost.next_dir);
                },
                .Frightened => {
                    // when inside the ghost house, show the normal ghost images
                    // (FIXME: ghost's inside the ghost house also show the
                    // frightened appearance when Pacman has eaten an energizer pill)
                    spriteImageGhostFrightened(ghost.type, since(ghost.frightened), levelSpec(state.game.round).fright_ticks - 60);
                },
                else => {
                    // show the regular ghost sprite image, the ghost's
                    // 'next_dir' is used to visualize the direction the ghost
                    // is heading to, this has the effect that ghosts already look
                    // into the direction they will move into one tile ahead
                    spriteImageGhost(ghost.type, ghost.next_dir, ghost.actor.anim_tick);
                }
            }
        }
    }

    // hide or display the currently active bonus fruit
    if (state.game.active_fruit == .None) {
        spriteFruit().enabled = false;
    }
    else {
        spriteFruit().* = .{
            .enabled = true,
            .pos = .{ 13 * TileWidth, 19 * TileHeight + TileHeight/2 },
            .tile = fruitSpriteCode(state.game.active_fruit),
            .color = fruitColorCode(state.game.active_fruit)
        };
    }
}

// render the intro screen
fn introTick() void {
    // on state enter, enable input and draw initial text
    if (now(state.intro.started)) {
        soundClear();
        gfxClearSprites();
        start(&state.gfx.fadein);
        inputEnable();
        gfxClear(TileCodeSpace, ColorCodeDefault);
        gfxText(.{3,0}, "1UP   HIGH SCORE   2UP");
        gfxColorScore(.{6,1}, ColorCodeDefault, 0);
        if (state.game.hiscore > 0) {
            gfxColorScore(.{16,1}, ColorCodeDefault, state.game.hiscore);
        }
        gfxText(.{7,5}, "CHARACTER / NICKNAME");
        gfxText(.{3,35}, "CREDIT 0");
    }

    // draw the animated 'ghost... name... nickname' lines
    var delay: u32 = 0;
    const names = [_][]const u8 { "-SHADOW", "-SPEEDY", "-BASHFUL", "-POKEY" };
    const nicknames = [_][]const u8 { "BLINKY", "PINKY", "INKY", "CLYDE" };
    for (names) |name, i| {
        const color: u8 = 2 * @intCast(u8,i) + 1;
        const y: i16 = 3 * @intCast(i16,i) + 6;
        
        // 2*3 tiles ghost image
        delay += 30;
        if (afterOnce(state.intro.started, delay)) {
            gfxColorTile(.{4,y+0}, color, TileCodeGhost+0); gfxColorTile(.{5,y+0}, color, TileCodeGhost+1);
            gfxColorTile(.{4,y+1}, color, TileCodeGhost+2); gfxColorTile(.{5,y+1}, color, TileCodeGhost+3);
            gfxColorTile(.{4,y+2}, color, TileCodeGhost+4); gfxColorTile(.{5,y+2}, color, TileCodeGhost+5);
        }
        // after 1 second, the name of the ghost
        delay += 60;
        if (afterOnce(state.intro.started, delay)) {
            gfxColorText(.{7,y+1}, color, name);
        }
        // after 0.5 seconds, the nickname of the ghost
        delay += 30;
        if (afterOnce(state.intro.started, delay)) {
            gfxColorText(.{17,y+1}, color, nicknames[i]);
        }
    }

    // . 10 PTS
    // o 50 PTS
    delay += 60;
    if (afterOnce(state.intro.started, delay)) {
        gfxColorTile(.{10,24}, ColorCodeDot, TileCodeDot);
        gfxText(.{12,24}, "10 \x5D\x5E\x5F");
        gfxColorTile(.{10,26}, ColorCodeDot, TileCodePill);
        gfxText(.{12,26}, "50 \x5D\x5E\x5F");
    }

    // blinking "press any key" text
    delay += 60;
    if (after(state.intro.started, delay)) {
        if (0 != (since(state.intro.started) & 0x20)) {
            gfxColorText(.{3,31}, 3, "                       ");
        }
        else {
            gfxColorText(.{3,31}, 3, "PRESS ANY KEY TO START!");
        }
    }

    // if a key is pressed, advance to game state
    if (state.input.anykey) {
        inputDisable();
        start(&state.gfx.fadeout);
        startAfter(&state.game.started, FadeTicks);
    }
}

//--- rendering system ---------------------------------------------------------
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
            data.tile_ram[y][x] = tile_code;
            data.color_ram[y][x] = color_code;
        }
    }
}

fn gfxClearPlayfieldToColor(color_code: u8) void {
    var y: usize = 3;
    while (y < (DisplayTilesY-2)): (y += 1) {
        var x: usize = 0;
        while (x < DisplayTilesX): (x += 1) {
            data.color_ram[y][x] = color_code;
        }
    }
}

fn gfxTileAt(pos: ivec2) u8 {
    return data.tile_ram[@intCast(usize,pos[1])][@intCast(usize,pos[0])];
}

fn gfxTile(pos: ivec2, tile_code: u8) void {
    data.tile_ram[@intCast(usize,pos[1])][@intCast(usize,pos[0])] = tile_code;
}

fn gfxColor(pos: ivec2, color_code: u8) void {
    data.color_ram[@intCast(usize,pos[1])][@intCast(usize,pos[0])] = color_code;
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

// print colored score number into tile+color buffers from right to left(!),
// scores are /10, the last printed number is always 0, 
// a zero-score will print as '00' (this is the same as on
// the Pacman arcade machine)
fn gfxColorScore(pos: ivec2, color_code: u8, score: u32) void {
    var p = pos;
    var s = score;
    gfxColorChar(p, color_code, '0');
    p[0] -= 1;
    var digit: u32 = 0;
    while (digit < 8): (digit += 1) {
        // FIXME: should this narrowing cast not be necessary?
        const chr: u8 = @intCast(u8, s % 10) + '0';
        if (validTilePos(p)) {
            gfxColorChar(p, color_code, chr);
            p[0] -= 1;
            s /= 10;
            if (0 == s) {
                break;
            }
        }
    }
}

// draw a colored tile-quad arranged as:
// |t+1|t+0|
// |t+3|t+2|
//
// This is (for instance) used to render the current "lives" and fruit
// symbols at the lower border.
//
fn gfxColorTileQuad(pos: ivec2, color_code: u8, tile_code: u8) void {
    var yy: i16 = 0;
    while (yy < 2): (yy += 1) {
        var xx: i16 = 0;
        while (xx < 2): (xx += 1) {
            const t: u8 = tile_code + @intCast(u8,yy)*2 + (1 - @intCast(u8,xx));
            gfxColorTile(pos + ivec2{xx,yy}, color_code, t);
        }
    }
}

// draw the fruit bonus score tiles (when Pacman has eaten the bonus fruit)
fn gfxFruitScore(fruit: Fruit) void {
    const color_code: u8 = if (fruit == .None) ColorCodeDot else ColorCodeFruitScore;
    const tiles: [4]u8 = switch (fruit) {
        .None =>        .{ 0x40, 0x40, 0x40, 0x40 },
        .Cherries =>    .{ 0x40, 0x81, 0x85, 0x40 },
        .Strawberry =>  .{ 0x40, 0x82, 0x85, 0x40 },
        .Peach =>       .{ 0x40, 0x83, 0x85, 0x40 },
        .Apple =>       .{ 0x40, 0x84, 0x85, 0x40 },
        .Grapes =>      .{ 0x40, 0x86, 0x8D, 0x8E },
        .Galaxian =>    .{ 0x87, 0x88, 0x8D, 0x8E },
        .Bell =>        .{ 0x89, 0x8A, 0x8D, 0x8E },
        .Key =>         .{ 0x8B, 0x8C, 0x8D, 0x8E },
    };
    var i: usize = 0;
    while (i < 4): (i += 1) {
        gfxColorTile(.{12+@intCast(i16,i),20}, color_code, tiles[i]);
    }
}

fn gfxClearSprites() void {
    for (state.gfx.sprites) |*spr| {
        spr.* = .{};
    }
}

// adjust viewport so that aspect ration is always correct
fn gfxAdjustViewport(canvas_width: i32, canvas_height: i32) void {
    assert((canvas_width > 0) and (canvas_height > 0));
    const fwidth = @intToFloat(f32, canvas_width);
    const fheight = @intToFloat(f32, canvas_height);
    const canvas_aspect = fwidth / fheight;
    const playfield_aspect = @intToFloat(f32, DisplayTilesX) / DisplayTilesY;
    const border = 10;
    if (playfield_aspect < canvas_aspect) {
        const vp_y: i32 = border;
        const vp_h: i32 = canvas_height - 2*border;
        const vp_w: i32 = @floatToInt(i32, fheight * playfield_aspect) - 2*border;
        // FIXME: why is /2 not possible here?
        const vp_x: i32 = (canvas_width - vp_w) >> 1;
        sg.applyViewport(vp_x, vp_y, vp_w, vp_h, true);
    }
    else {
        const vp_x: i32 = border;
        const vp_w: i32 = canvas_width - 2*border;
        const vp_h: i32 = @floatToInt(i32, fwidth / playfield_aspect) - 2*border;
        // FIXME: why is /2 not possible here?
        const vp_y: i32 = (canvas_height - vp_h) >> 1;
        sg.applyViewport(vp_x, vp_y, vp_w, vp_h, true);
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
    sg.updateBuffer(state.gfx.offscreen.vbuf, &data.vertices, @intCast(i32, state.gfx.num_vertices * @sizeOf(Vertex)));

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
    gfxAdjustViewport(canvas_width, canvas_height);
    sg.applyPipeline(state.gfx.display.pip);
    sg.applyBindings(state.gfx.display.bind);
    sg.draw(0, 4, 1);
    sg.endPass();
    sg.commit();
}

fn gfxAddVertex(x: f32, y: f32, u: f32, v: f32, color_code: u32, opacity: u32) void {
    var vtx: *Vertex = &data.vertices[state.gfx.num_vertices];
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
    if (before(state.gfx.fadein, FadeTicks)) {
        const t = @intToFloat(f32, since(state.gfx.fadein)) / FadeTicks;
        state.gfx.fade = @floatToInt(u8, 255.0 * (1.0 - t));
    }
    if (afterOnce(state.gfx.fadein, FadeTicks)) {
        state.gfx.fade = 0;
    }
    if (before(state.gfx.fadeout, FadeTicks)) {
        const t = @intToFloat(f32, since(state.gfx.fadeout)) / FadeTicks;
        state.gfx.fade = @floatToInt(u8, 255.0 * t);
    }
    if (afterOnce(state.gfx.fadeout, FadeTicks)) {
        state.gfx.fade = 255;
    }
}

fn gfxAddPlayfieldVertices() void {
    var y: u32 = 0;
    while (y < DisplayTilesY): (y += 1) {
        var x: u32 = 0;
        while (x < DisplayTilesX): (x += 1) {
            const tile_code = data.tile_ram[y][x];
            const color_code = data.color_ram[y][x] & 0x1F;
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
    for (state.gfx.debug_markers) |*dbg| {
        if (dbg.enabled) {
            gfxAddTileVertices(@intCast(u32, dbg.tile_pos[0]), @intCast(u32, dbg.tile_pos[1]), dbg.tile, dbg.color);
        }
    }
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
            data.tile_pixels[dst_y + y][dst_x + x] = p;
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
            data.tile_pixels[y][x] = 1;
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
    for (data.color_palette) |*pt, i| {
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
        .size = @sizeOf(@TypeOf(data.vertices))
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
            .D3D11    => @embedFile("shaders/offscreen_vs.hlsl"),
            .GLCORE33 => @embedFile("shaders/offscreen_vs.v330.glsl"),
            else => unreachable,
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11    => @embedFile("shaders/offscreen_fs.hlsl"),
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
            .D3D11    => @embedFile("shaders/display_vs.hlsl"),
            .GLCORE33 => @embedFile("shaders/display_vs.v330.glsl"),
            else => unreachable
        };
        shd_desc.fs.source = switch(sg.queryBackend()) {
            .D3D11    => @embedFile("shaders/display_fs.hlsl"), 
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
            .ptr = &data.tile_pixels,
            .size = @sizeOf(@TypeOf(data.tile_pixels))
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
            .ptr = &data.color_palette,
            .size = @sizeOf(@TypeOf(data.color_palette))
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

//--- audio system -------------------------------------------------------------
fn soundInit() void {
    saudio.setup(.{});

    // compute sample duration in nanoseconds
    const samples_per_sec: i32 = saudio.sampleRate();
    state.audio.sample_duration_ns = @divTrunc(1_000_000_000, samples_per_sec);

    // compute number of 96kHz ticks per sample tick (the Namco sound 
    // generator runs at 96kHz), times 1000 for increased precision
    state.audio.voice_tick_period = @divTrunc(96_000_000, samples_per_sec);
}

fn soundShutdown() void {
    saudio.shutdown();
}

// update the Namco sound generator emulation, must be called at 96Khz
const WaveTableRom = @embedFile("roms/pacman_wavetable.rom");
fn soundVoiceTick() void {
    for (state.audio.voices) |*voice| {
        voice.counter +%= voice.frequency;  // NOTE: add with wraparound
        // lookup current 4-bit sample from waveform index and
        // topmost 5 bits of the frequency counter
        const wave_index: u8 = (@intCast(u8,voice.waveform) << 5) | @intCast(u8, voice.counter >> 15);
        // sample is (-8..+7) * 16 -> -128 .. +127
        const sample: i32 = (@intCast(i32, WaveTableRom[wave_index] & 0xF) - 8) * voice.volume;
        voice.sample_acc += @intToFloat(f32, sample);
        voice.sample_div += 128.0;
    }
}

// the per-sample tick function must be called with the playback sample rate (e.g. 44.1kHz)
fn soundSampleTick() void {
    var sm: f32 = 0.0;
    for (state.audio.voices) |*voice| {
        if (voice.sample_div > 0.0) {
            sm += voice.sample_acc / voice.sample_div;
            voice.sample_acc = 0.0;
            voice.sample_div = 0.0;
        }
    }
    data.sample_buffer[state.audio.num_samples] = sm * 0.33333 * AudioVolume;
    state.audio.num_samples += 1;
    if (state.audio.num_samples == NumSamples) {
        _ = saudio.push(&data.sample_buffer[0], NumSamples);
        state.audio.num_samples = 0;
    }
}

// the sound systems per-frame function
fn soundFrame(frame_time_ns: i32) void {
    // for each sample to generate...
    state.audio.sample_accum -= frame_time_ns;
    while (state.audio.sample_accum < 0) {
        state.audio.sample_accum += state.audio.sample_duration_ns;
        // tick the sound generator at 96kHz
        state.audio.voice_tick_accum -= state.audio.voice_tick_period;
        while (state.audio.voice_tick_accum < 0) {
            state.audio.voice_tick_accum += 1000;
            soundVoiceTick();
        }
        // generate new sample into local sample buffer, and push to sokol-audio if buffer full
        soundSampleTick();
    }
}

// the sound system's 60Hz tick function which takes care of sound-effect playback
fn soundTick() void {
    for (state.audio.sounds) |*sound, sound_slot| {
        if (sound.func) |func| {
            // this is a procedural sound effect
            func(sound_slot);
        }
        else if (sound.dump) |dump| {
            // this is a register dump sound effect
            if (sound.cur_tick == sound.num_ticks) {
                soundStop(sound_slot);
                continue;
            }

            // decode register dump values into voice registers
            var dump_index = sound.cur_tick * sound.stride;
            for (state.audio.voices) |*voice, i| {
                if (sound.voice[i]) {
                    const val: u32 = dump[dump_index];
                    dump_index += 1;
                    // FIXME Zig: intCasts shouldn't be necessary here, because the '&'
                    // ensures that the result fits?
                    // 20 bits frequency
                    voice.frequency = @intCast(u20, val & ((1<<20)-1));
                    // 3 bits waveform
                    voice.waveform = @intCast(u3, (val>>24) & 7);
                    // 4 bits volume
                    voice.volume = @intCast(u4, (val>>28) & 15);
                }
            }
        }
        sound.cur_tick += 1;
    }
}

// clear all active sound effects and start outputting silence
fn soundClear() void {
    for (state.audio.voices) |*voice| {
        voice.* = .{};
    }
    for (state.audio.sounds) |*sound| {
        sound.* = .{};
    }
}

// stop a sound effect
fn soundStop(sound_slot: usize) void {
    for (state.audio.voices) |*voice, i| {
        if (state.audio.sounds[sound_slot].voice[i]) {
            voice.* = .{};
        }
    }
    state.audio.sounds[sound_slot] = .{};
}

// start a sound effect
fn soundStart(sound_slot: usize, desc: SoundDesc) void {
    var sound = &state.audio.sounds[sound_slot];
    sound.* = .{};
    sound.voice = desc.voice;
    sound.func = desc.func;
    sound.dump = desc.dump;
    if (sound.dump) |dump| {
        for (sound.voice) |voice_active| {
            if (voice_active) {
                sound.stride += 1;
            }
        }
        assert(sound.stride > 0);
        sound.num_ticks = @intCast(u32, dump.len) / sound.stride;
    }
}

// start procedural sound effect to eat dot (there's two separate 
// sound effects for eating dots, one going up and one going down)
fn soundEatDot(dots_eaten: u32) void {
    if (0 != (dots_eaten & 1)) {
        soundStart(2, .{
            .func = soundFuncEatDot1,
            .voice = .{ false, false, true }
        });
    }
    else {
        soundStart(2, .{
            .func = soundFuncEatDot2,
            .voice = .{ false, false, true }
        });
    }
}

// start sound effect for playing the prelude song, this is a register dump effect
fn soundPrelude() void {
    soundStart(0, .{
        .dump = SoundDumpPrelude[0..],
        .voice = .{ true, true, false }
    });
}

// start the Pacman dying sound effect
fn soundDead() void {
    soundStart(2, .{
        .dump = SoundDumpDead[0..],
        .voice = .{ false, false, true }
    });
}

// start sound effect to eat a ghost
fn soundEatGhost() void {
    soundStart(2, .{
        .func = soundFuncEatGhost,
        .voice = .{ false, false, true }
    });
}

// start sound effect for eating the bonus fruit
fn soundEatFruit() void {
    soundStart(2, .{
        .func = soundFuncEatFruit,
        .voice = .{ false, false, true }
    });
}

// start the "weeooh" sound effect which plays in the background
fn soundWeeooh() void {
    soundStart(1, .{
        .func = soundFuncWeeooh,
        .voice = .{ false, true, false }
    });
}

// start the frightened sound (replaces the weeooh sound after energizer pill eaten)
fn soundFrightened() void {
    soundStart(1, .{
        .func = soundFuncFrightened,
        .voice = .{ false, true, false }
    });
}

// procedural sound effect callback functions
fn soundFuncEatDot1(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[2];
    if (sound.cur_tick == 0) {
        voice.volume = 12;
        voice.waveform = 2;
        voice.frequency = 0x1500;
    }
    else if (sound.cur_tick == 5) {
        soundStop(slot);
    }
    else {
        voice.frequency -= 0x300;
    }
}

fn soundFuncEatDot2(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[2];
    if (sound.cur_tick == 0) {
        voice.volume = 12;
        voice.waveform = 2;
        voice.frequency = 0x700;
    }
    else if (sound.cur_tick == 5) {
        soundStop(slot);
    }
    else {
        voice.frequency += 0x300;
    }
}

fn soundFuncEatGhost(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[2];
    if (sound.cur_tick == 0) {
        voice.volume = 12;
        voice.waveform = 5;
        voice.frequency = 0;
    }
    else if (sound.cur_tick == 32) {
        soundStop(slot);
    }
    else {
        voice.frequency += 20;
    }
}

fn soundFuncEatFruit(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[2];
    if (sound.cur_tick == 0) {
        voice.volume = 15;
        voice.waveform = 6;
        voice.frequency = 0x1600;
    }
    else if (sound.cur_tick == 23) {
        soundStop(slot);
    }
    else if (sound.cur_tick < 11) {
        voice.frequency -= 0x200;
    }
    else {
        voice.frequency += 0x200;
    }
}

fn soundFuncWeeooh(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[1];
    if (sound.cur_tick == 0) {
        voice.volume = 6;
        voice.waveform = 6;
        voice.frequency = 0x1000;
    }
    else if ((sound.cur_tick % 24) < 12) {
        voice.frequency += 0x200;
    }
    else {
        voice.frequency -= 0x200;
    }
}

fn soundFuncFrightened(slot: usize) void {
    const sound = &state.audio.sounds[slot];
    var voice = &state.audio.voices[1];
    if (sound.cur_tick == 0) {
        voice.volume = 10;
        voice.waveform = 4;
        voice.frequency = 0x180;
    }
    else if ((sound.cur_tick % 8) == 0) {
        voice.frequency = 0x180;
    }
    else {
        voice.frequency += 0x180;
    }
}

//--- sokol-app callbacks ------------------------------------------------------
export fn init() void {
    stm.setup();
    gfxInit();
    soundInit();
    if (DbgSkipIntro) {
        start(&state.game.started);
    }
    else {
        start(&state.intro.started);
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

        // call the per-tick sound update function
        soundTick();

        // check for game mode change
        if (now(state.intro.started)) {
            state.game_mode = .Intro;
        }
        if (now(state.game.started)) {
            state.game_mode = .Game;
        }

        // call the top-level game mode tick function
        switch (state.game_mode) {
            .Intro => introTick(),
            .Game => gameTick(),
        }
    }
    gfxFrame();
    soundFrame(@floatToInt(i32, frame_time_ns));
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    if ((event.type == .KEY_DOWN) or (event.type == .KEY_UP)) {
        const key_pressed = event.type == .KEY_DOWN;
        if (state.input.enabled) {
            state.input.anykey = key_pressed;
            switch (event.key_code) {
                .W, .UP,    => state.input.up = key_pressed,
                .S, .DOWN,  => state.input.down = key_pressed,
                .A, .LEFT,  => state.input.left = key_pressed,
                .D, .RIGHT, => state.input.right = key_pressed,
                .ESCAPE     => state.input.esc = key_pressed,
                else => {}
            }
        }
    }
}

export fn cleanup() void {
    soundShutdown();
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

//-- Sound Effect Register Dumps -----------------------------------------------

//  Each line is a 'register dump' for one 60Hz tick. Each 32-bit number
//  encodes the per-voice values for frequency, waveform and volume:
//
//  31                              0 bit
//  |vvvv-www----ffffffffffffffffffff|
//    |    |              |
//    |    |              +-- 20 bits frequency
//    |    +-- 3 bits waveform
//    +-- 4 bits volume
 
const SoundDumpPrelude = [490]u32 {
    0xE20002E0, 0xF0001700,
    0xD20002E0, 0xF0001700,
    0xC20002E0, 0xF0001700,
    0xB20002E0, 0xF0001700,
    0xA20002E0, 0xF0000000,
    0x920002E0, 0xF0000000,
    0x820002E0, 0xF0000000,
    0x720002E0, 0xF0000000,
    0x620002E0, 0xF0002E00,
    0x520002E0, 0xF0002E00,
    0x420002E0, 0xF0002E00,
    0x320002E0, 0xF0002E00,
    0x220002E0, 0xF0000000,
    0x120002E0, 0xF0000000,
    0x020002E0, 0xF0000000,
    0xE2000000, 0xF0002280,
    0xD2000000, 0xF0002280,
    0xC2000000, 0xF0002280,
    0xB2000000, 0xF0002280,
    0xA2000000, 0xF0000000,
    0x92000000, 0xF0000000,
    0x82000000, 0xF0000000,
    0x72000000, 0xF0000000,
    0xE2000450, 0xF0001D00,
    0xD2000450, 0xF0001D00,
    0xC2000450, 0xF0001D00,
    0xB2000450, 0xF0001D00,
    0xA2000450, 0xF0000000,
    0x92000450, 0xF0000000,
    0x82000450, 0xF0000000,
    0x72000450, 0xF0000000,
    0xE20002E0, 0xF0002E00,
    0xD20002E0, 0xF0002E00,
    0xC20002E0, 0xF0002E00,
    0xB20002E0, 0xF0002E00,
    0xA20002E0, 0xF0002280,
    0x920002E0, 0xF0002280,
    0x820002E0, 0xF0002280,
    0x720002E0, 0xF0002280,
    0x620002E0, 0xF0000000,
    0x520002E0, 0xF0000000,
    0x420002E0, 0xF0000000,
    0x320002E0, 0xF0000000,
    0x220002E0, 0xF0000000,
    0x120002E0, 0xF0000000,
    0x020002E0, 0xF0000000,
    0xE2000000, 0xF0001D00,
    0xD2000000, 0xF0001D00,
    0xC2000000, 0xF0001D00,
    0xB2000000, 0xF0001D00,
    0xA2000000, 0xF0001D00,
    0x92000000, 0xF0001D00,
    0x82000000, 0xF0001D00,
    0x72000000, 0xF0001D00,
    0xE2000450, 0xF0000000,
    0xD2000450, 0xF0000000,
    0xC2000450, 0xF0000000,
    0xB2000450, 0xF0000000,
    0xA2000450, 0xF0000000,
    0x92000450, 0xF0000000,
    0x82000450, 0xF0000000,
    0x72000450, 0xF0000000,
    0xE2000308, 0xF0001840,
    0xD2000308, 0xF0001840,
    0xC2000308, 0xF0001840,
    0xB2000308, 0xF0001840,
    0xA2000308, 0xF0000000,
    0x92000308, 0xF0000000,
    0x82000308, 0xF0000000,
    0x72000308, 0xF0000000,
    0x62000308, 0xF00030C0,
    0x52000308, 0xF00030C0,
    0x42000308, 0xF00030C0,
    0x32000308, 0xF00030C0,
    0x22000308, 0xF0000000,
    0x12000308, 0xF0000000,
    0x02000308, 0xF0000000,
    0xE2000000, 0xF0002480,
    0xD2000000, 0xF0002480,
    0xC2000000, 0xF0002480,
    0xB2000000, 0xF0002480,
    0xA2000000, 0xF0000000,
    0x92000000, 0xF0000000,
    0x82000000, 0xF0000000,
    0x72000000, 0xF0000000,
    0xE2000490, 0xF0001EC0,
    0xD2000490, 0xF0001EC0,
    0xC2000490, 0xF0001EC0,
    0xB2000490, 0xF0001EC0,
    0xA2000490, 0xF0000000,
    0x92000490, 0xF0000000,
    0x82000490, 0xF0000000,
    0x72000490, 0xF0000000,
    0xE2000308, 0xF00030C0,
    0xD2000308, 0xF00030C0,
    0xC2000308, 0xF00030C0,
    0xB2000308, 0xF00030C0,
    0xA2000308, 0xF0002480,
    0x92000308, 0xF0002480,
    0x82000308, 0xF0002480,
    0x72000308, 0xF0002480,
    0x62000308, 0xF0000000,
    0x52000308, 0xF0000000,
    0x42000308, 0xF0000000,
    0x32000308, 0xF0000000,
    0x22000308, 0xF0000000,
    0x12000308, 0xF0000000,
    0x02000308, 0xF0000000,
    0xE2000000, 0xF0001EC0,
    0xD2000000, 0xF0001EC0,
    0xC2000000, 0xF0001EC0,
    0xB2000000, 0xF0001EC0,
    0xA2000000, 0xF0001EC0,
    0x92000000, 0xF0001EC0,
    0x82000000, 0xF0001EC0,
    0x72000000, 0xF0001EC0,
    0xE2000490, 0xF0000000,
    0xD2000490, 0xF0000000,
    0xC2000490, 0xF0000000,
    0xB2000490, 0xF0000000,
    0xA2000490, 0xF0000000,
    0x92000490, 0xF0000000,
    0x82000490, 0xF0000000,
    0x72000490, 0xF0000000,
    0xE20002E0, 0xF0001700,
    0xD20002E0, 0xF0001700,
    0xC20002E0, 0xF0001700,
    0xB20002E0, 0xF0001700,
    0xA20002E0, 0xF0000000,
    0x920002E0, 0xF0000000,
    0x820002E0, 0xF0000000,
    0x720002E0, 0xF0000000,
    0x620002E0, 0xF0002E00,
    0x520002E0, 0xF0002E00,
    0x420002E0, 0xF0002E00,
    0x320002E0, 0xF0002E00,
    0x220002E0, 0xF0000000,
    0x120002E0, 0xF0000000,
    0x020002E0, 0xF0000000,
    0xE2000000, 0xF0002280,
    0xD2000000, 0xF0002280,
    0xC2000000, 0xF0002280,
    0xB2000000, 0xF0002280,
    0xA2000000, 0xF0000000,
    0x92000000, 0xF0000000,
    0x82000000, 0xF0000000,
    0x72000000, 0xF0000000,
    0xE2000450, 0xF0001D00,
    0xD2000450, 0xF0001D00,
    0xC2000450, 0xF0001D00,
    0xB2000450, 0xF0001D00,
    0xA2000450, 0xF0000000,
    0x92000450, 0xF0000000,
    0x82000450, 0xF0000000,
    0x72000450, 0xF0000000,
    0xE20002E0, 0xF0002E00,
    0xD20002E0, 0xF0002E00,
    0xC20002E0, 0xF0002E00,
    0xB20002E0, 0xF0002E00,
    0xA20002E0, 0xF0002280,
    0x920002E0, 0xF0002280,
    0x820002E0, 0xF0002280,
    0x720002E0, 0xF0002280,
    0x620002E0, 0xF0000000,
    0x520002E0, 0xF0000000,
    0x420002E0, 0xF0000000,
    0x320002E0, 0xF0000000,
    0x220002E0, 0xF0000000,
    0x120002E0, 0xF0000000,
    0x020002E0, 0xF0000000,
    0xE2000000, 0xF0001D00,
    0xD2000000, 0xF0001D00,
    0xC2000000, 0xF0001D00,
    0xB2000000, 0xF0001D00,
    0xA2000000, 0xF0001D00,
    0x92000000, 0xF0001D00,
    0x82000000, 0xF0001D00,
    0x72000000, 0xF0001D00,
    0xE2000450, 0xF0000000,
    0xD2000450, 0xF0000000,
    0xC2000450, 0xF0000000,
    0xB2000450, 0xF0000000,
    0xA2000450, 0xF0000000,
    0x92000450, 0xF0000000,
    0x82000450, 0xF0000000,
    0x72000450, 0xF0000000,
    0xE2000450, 0xF0001B40,
    0xD2000450, 0xF0001B40,
    0xC2000450, 0xF0001B40,
    0xB2000450, 0xF0001B40,
    0xA2000450, 0xF0001D00,
    0x92000450, 0xF0001D00,
    0x82000450, 0xF0001D00,
    0x72000450, 0xF0001D00,
    0x62000450, 0xF0001EC0,
    0x52000450, 0xF0001EC0,
    0x42000450, 0xF0001EC0,
    0x32000450, 0xF0001EC0,
    0x22000450, 0xF0000000,
    0x12000450, 0xF0000000,
    0x02000450, 0xF0000000,
    0xE20004D0, 0xF0001EC0,
    0xD20004D0, 0xF0001EC0,
    0xC20004D0, 0xF0001EC0,
    0xB20004D0, 0xF0001EC0,
    0xA20004D0, 0xF0002080,
    0x920004D0, 0xF0002080,
    0x820004D0, 0xF0002080,
    0x720004D0, 0xF0002080,
    0x620004D0, 0xF0002280,
    0x520004D0, 0xF0002280,
    0x420004D0, 0xF0002280,
    0x320004D0, 0xF0002280,
    0x220004D0, 0xF0000000,
    0x120004D0, 0xF0000000,
    0x020004D0, 0xF0000000,
    0xE2000568, 0xF0002280,
    0xD2000568, 0xF0002280,
    0xC2000568, 0xF0002280,
    0xB2000568, 0xF0002280,
    0xA2000568, 0xF0002480,
    0x92000568, 0xF0002480,
    0x82000568, 0xF0002480,
    0x72000568, 0xF0002480,
    0x62000568, 0xF0002680,
    0x52000568, 0xF0002680,
    0x42000568, 0xF0002680,
    0x32000568, 0xF0002680,
    0x22000568, 0xF0000000,
    0x12000568, 0xF0000000,
    0x02000568, 0xF0000000,
    0xE20005C0, 0xF0002E00,
    0xD20005C0, 0xF0002E00,
    0xC20005C0, 0xF0002E00,
    0xB20005C0, 0xF0002E00,
    0xA20005C0, 0xF0002E00,
    0x920005C0, 0xF0002E00,
    0x820005C0, 0xF0002E00,
    0x720005C0, 0xF0002E00,
    0x620005C0, 0x00000E80,
    0x520005C0, 0x00000E80,
    0x420005C0, 0x00000E80,
    0x320005C0, 0x00000E80,
    0x220005C0, 0x00000E80,
    0x120005C0, 0x00000E80,
};

const SoundDumpDead = [90]u32 {
    0xF1001F00,
    0xF1001E00,
    0xF1001D00,
    0xF1001C00,
    0xF1001B00,
    0xF1001C00,
    0xF1001D00,
    0xF1001E00,
    0xF1001F00,
    0xF1002000,
    0xF1002100,
    0xE1001D00,
    0xE1001C00,
    0xE1001B00,
    0xE1001A00,
    0xE1001900,
    0xE1001800,
    0xE1001900,
    0xE1001A00,
    0xE1001B00,
    0xE1001C00,
    0xE1001D00,
    0xE1001E00,
    0xD1001B00,
    0xD1001A00,
    0xD1001900,
    0xD1001800,
    0xD1001700,
    0xD1001600,
    0xD1001700,
    0xD1001800,
    0xD1001900,
    0xD1001A00,
    0xD1001B00,
    0xD1001C00,
    0xC1001900,
    0xC1001800,
    0xC1001700,
    0xC1001600,
    0xC1001500,
    0xC1001400,
    0xC1001500,
    0xC1001600,
    0xC1001700,
    0xC1001800,
    0xC1001900,
    0xC1001A00,
    0xB1001700,
    0xB1001600,
    0xB1001500,
    0xB1001400,
    0xB1001300,
    0xB1001200,
    0xB1001300,
    0xB1001400,
    0xB1001500,
    0xB1001600,
    0xB1001700,
    0xB1001800,
    0xA1001500,
    0xA1001400,
    0xA1001300,
    0xA1001200,
    0xA1001100,
    0xA1001000,
    0xA1001100,
    0xA1001200,
    0x80000800,
    0x80001000,
    0x80001800,
    0x80002000,
    0x80002800,
    0x80003000,
    0x80003800,
    0x80004000,
    0x80004800,
    0x80005000,
    0x80005800,
    0x00000000,
    0x80000800,
    0x80001000,
    0x80001800,
    0x80002000,
    0x80002800,
    0x80003000,
    0x80003800,
    0x80004000,
    0x80004800,
    0x80005000,
    0x80005800,
};
