// machine generated, do not edit

// helper function to convert "anything" to a Range struct
pub fn asRange(val: anytype) Range {
    const type_info = @typeInfo(@TypeOf(val));
    switch (type_info) {
        .Pointer => {
            switch (type_info.Pointer.size) {
                .One => return .{ .ptr = val, .size = @sizeOf(type_info.Pointer.child) },
                .Slice => return .{ .ptr = val.ptr, .size = @sizeOf(type_info.Pointer.child) * val.len },
                else => @compileError("FIXME: Pointer type!"),
            }
        },
        .Struct, .Array => {
            return .{ .ptr = &val, .size = @sizeOf(@TypeOf(val)) };
        },
        else => {
            @compileError("Cannot convert to range!");
        },
    }
}

pub const Buffer = extern struct {
    id: u32 = 0,
};
pub const Image = extern struct {
    id: u32 = 0,
};
pub const Shader = extern struct {
    id: u32 = 0,
};
pub const Pipeline = extern struct {
    id: u32 = 0,
};
pub const Pass = extern struct {
    id: u32 = 0,
};
pub const Context = extern struct {
    id: u32 = 0,
};
pub const Range = extern struct {
    ptr: ?*const c_void = null,
    size: usize = 0,
};
pub const invalid_id = 0;
pub const num_shader_stages = 2;
pub const num_inflight_frames = 2;
pub const max_color_attachments = 4;
pub const max_shaderstage_buffers = 8;
pub const max_shaderstage_images = 12;
pub const max_shaderstage_ubs = 4;
pub const max_ub_members = 16;
pub const max_vertex_attributes = 16;
pub const max_mipmaps = 16;
pub const max_texturearray_layers = 128;
pub const Color = extern struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,
};
pub const Backend = enum(c_int) {
    GLCORE33,
    GLES2,
    GLES3,
    D3D11,
    METAL_IOS,
    METAL_MACOS,
    METAL_SIMULATOR,
    WGPU,
    DUMMY,
};
pub const PixelFormat = enum(c_int) {
    DEFAULT,
    NONE,
    R8,
    R8SN,
    R8UI,
    R8SI,
    R16,
    R16SN,
    R16UI,
    R16SI,
    R16F,
    RG8,
    RG8SN,
    RG8UI,
    RG8SI,
    R32UI,
    R32SI,
    R32F,
    RG16,
    RG16SN,
    RG16UI,
    RG16SI,
    RG16F,
    RGBA8,
    RGBA8SN,
    RGBA8UI,
    RGBA8SI,
    BGRA8,
    RGB10A2,
    RG11B10F,
    RG32UI,
    RG32SI,
    RG32F,
    RGBA16,
    RGBA16SN,
    RGBA16UI,
    RGBA16SI,
    RGBA16F,
    RGBA32UI,
    RGBA32SI,
    RGBA32F,
    DEPTH,
    DEPTH_STENCIL,
    BC1_RGBA,
    BC2_RGBA,
    BC3_RGBA,
    BC4_R,
    BC4_RSN,
    BC5_RG,
    BC5_RGSN,
    BC6H_RGBF,
    BC6H_RGBUF,
    BC7_RGBA,
    PVRTC_RGB_2BPP,
    PVRTC_RGB_4BPP,
    PVRTC_RGBA_2BPP,
    PVRTC_RGBA_4BPP,
    ETC2_RGB8,
    ETC2_RGB8A1,
    ETC2_RGBA8,
    ETC2_RG11,
    ETC2_RG11SN,
    NUM,
};
pub const PixelformatInfo = extern struct {
    sample: bool = false,
    filter: bool = false,
    render: bool = false,
    blend: bool = false,
    msaa: bool = false,
    depth: bool = false,
    __pad: [3]u32 = [_]u32{0} ** 3,
};
pub const Features = extern struct {
    instancing: bool = false,
    origin_top_left: bool = false,
    multiple_render_targets: bool = false,
    msaa_render_targets: bool = false,
    imagetype_3d: bool = false,
    imagetype_array: bool = false,
    image_clamp_to_border: bool = false,
    mrt_independent_blend_state: bool = false,
    mrt_independent_write_mask: bool = false,
    __pad: [3]u32 = [_]u32{0} ** 3,
};
pub const Limits = extern struct {
    max_image_size_2d: i32 = 0,
    max_image_size_cube: i32 = 0,
    max_image_size_3d: i32 = 0,
    max_image_size_array: i32 = 0,
    max_image_array_layers: i32 = 0,
    max_vertex_attrs: i32 = 0,
    gl_max_vertex_uniform_vectors: i32 = 0,
};
pub const ResourceState = enum(c_int) {
    INITIAL,
    ALLOC,
    VALID,
    FAILED,
    INVALID,
};
pub const Usage = enum(c_int) {
    DEFAULT,
    IMMUTABLE,
    DYNAMIC,
    STREAM,
    NUM,
};
pub const BufferType = enum(c_int) {
    DEFAULT,
    VERTEXBUFFER,
    INDEXBUFFER,
    NUM,
};
pub const IndexType = enum(c_int) {
    DEFAULT,
    NONE,
    UINT16,
    UINT32,
    NUM,
};
pub const ImageType = enum(c_int) {
    DEFAULT,
    _2D,
    CUBE,
    _3D,
    ARRAY,
    NUM,
};
pub const SamplerType = enum(c_int) {
    DEFAULT,
    FLOAT,
    SINT,
    UINT,
};
pub const CubeFace = enum(c_int) {
    POS_X,
    NEG_X,
    POS_Y,
    NEG_Y,
    POS_Z,
    NEG_Z,
    NUM,
};
pub const ShaderStage = enum(c_int) {
    VS,
    FS,
};
pub const PrimitiveType = enum(c_int) {
    DEFAULT,
    POINTS,
    LINES,
    LINE_STRIP,
    TRIANGLES,
    TRIANGLE_STRIP,
    NUM,
};
pub const Filter = enum(c_int) {
    DEFAULT,
    NEAREST,
    LINEAR,
    NEAREST_MIPMAP_NEAREST,
    NEAREST_MIPMAP_LINEAR,
    LINEAR_MIPMAP_NEAREST,
    LINEAR_MIPMAP_LINEAR,
    NUM,
};
pub const Wrap = enum(c_int) {
    DEFAULT,
    REPEAT,
    CLAMP_TO_EDGE,
    CLAMP_TO_BORDER,
    MIRRORED_REPEAT,
    NUM,
};
pub const BorderColor = enum(c_int) {
    DEFAULT,
    TRANSPARENT_BLACK,
    OPAQUE_BLACK,
    OPAQUE_WHITE,
    NUM,
};
pub const VertexFormat = enum(c_int) {
    INVALID,
    FLOAT,
    FLOAT2,
    FLOAT3,
    FLOAT4,
    BYTE4,
    BYTE4N,
    UBYTE4,
    UBYTE4N,
    SHORT2,
    SHORT2N,
    USHORT2N,
    SHORT4,
    SHORT4N,
    USHORT4N,
    UINT10_N2,
    NUM,
};
pub const VertexStep = enum(c_int) {
    DEFAULT,
    PER_VERTEX,
    PER_INSTANCE,
    NUM,
};
pub const UniformType = enum(c_int) {
    INVALID,
    FLOAT,
    FLOAT2,
    FLOAT3,
    FLOAT4,
    MAT4,
    NUM,
};
pub const CullMode = enum(c_int) {
    DEFAULT,
    NONE,
    FRONT,
    BACK,
    NUM,
};
pub const FaceWinding = enum(c_int) {
    DEFAULT,
    CCW,
    CW,
    NUM,
};
pub const CompareFunc = enum(c_int) {
    DEFAULT,
    NEVER,
    LESS,
    EQUAL,
    LESS_EQUAL,
    GREATER,
    NOT_EQUAL,
    GREATER_EQUAL,
    ALWAYS,
    NUM,
};
pub const StencilOp = enum(c_int) {
    DEFAULT,
    KEEP,
    ZERO,
    REPLACE,
    INCR_CLAMP,
    DECR_CLAMP,
    INVERT,
    INCR_WRAP,
    DECR_WRAP,
    NUM,
};
pub const BlendFactor = enum(c_int) {
    DEFAULT,
    ZERO,
    ONE,
    SRC_COLOR,
    ONE_MINUS_SRC_COLOR,
    SRC_ALPHA,
    ONE_MINUS_SRC_ALPHA,
    DST_COLOR,
    ONE_MINUS_DST_COLOR,
    DST_ALPHA,
    ONE_MINUS_DST_ALPHA,
    SRC_ALPHA_SATURATED,
    BLEND_COLOR,
    ONE_MINUS_BLEND_COLOR,
    BLEND_ALPHA,
    ONE_MINUS_BLEND_ALPHA,
    NUM,
};
pub const BlendOp = enum(c_int) {
    DEFAULT,
    ADD,
    SUBTRACT,
    REVERSE_SUBTRACT,
    NUM,
};
pub const ColorMask = enum(c_int) {
    DEFAULT = 0,
    NONE = 16,
    R = 1,
    G = 2,
    RG = 3,
    B = 4,
    RB = 5,
    GB = 6,
    RGB = 7,
    A = 8,
    RA = 9,
    GA = 10,
    RGA = 11,
    BA = 12,
    RBA = 13,
    GBA = 14,
    RGBA = 15,
};
pub const Action = enum(c_int) {
    DEFAULT,
    CLEAR,
    LOAD,
    DONTCARE,
    NUM,
};
pub const ColorAttachmentAction = extern struct {
    action: Action = .DEFAULT,
    value: Color = .{},
};
pub const DepthAttachmentAction = extern struct {
    action: Action = .DEFAULT,
    value: f32 = 0.0,
};
pub const StencilAttachmentAction = extern struct {
    action: Action = .DEFAULT,
    value: u8 = 0,
};
pub const PassAction = extern struct {
    _start_canary: u32 = 0,
    colors: [4]ColorAttachmentAction = [_]ColorAttachmentAction{.{}} ** 4,
    depth: DepthAttachmentAction = .{},
    stencil: StencilAttachmentAction = .{},
    _end_canary: u32 = 0,
};
pub const Bindings = extern struct {
    _start_canary: u32 = 0,
    vertex_buffers: [8]Buffer = [_]Buffer{.{}} ** 8,
    vertex_buffer_offsets: [8]i32 = [_]i32{0} ** 8,
    index_buffer: Buffer = .{},
    index_buffer_offset: i32 = 0,
    vs_images: [12]Image = [_]Image{.{}} ** 12,
    fs_images: [12]Image = [_]Image{.{}} ** 12,
    _end_canary: u32 = 0,
};
pub const BufferDesc = extern struct {
    _start_canary: u32 = 0,
    size: usize = 0,
    type: BufferType = .DEFAULT,
    usage: Usage = .DEFAULT,
    data: Range = .{},
    label: [*c]const u8 = null,
    gl_buffers: [2]u32 = [_]u32{0} ** 2,
    mtl_buffers: [2]?*const c_void = [_]?*const c_void{null} ** 2,
    d3d11_buffer: ?*const c_void = null,
    wgpu_buffer: ?*const c_void = null,
    _end_canary: u32 = 0,
};
pub const ImageData = extern struct {
    subimage: [6][16]Range = [_][16]Range{[_]Range{.{}} ** 16} ** 6,
};
pub const ImageDesc = extern struct {
    _start_canary: u32 = 0,
    type: ImageType = .DEFAULT,
    render_target: bool = false,
    width: i32 = 0,
    height: i32 = 0,
    num_slices: i32 = 0,
    num_mipmaps: i32 = 0,
    usage: Usage = .DEFAULT,
    pixel_format: PixelFormat = .DEFAULT,
    sample_count: i32 = 0,
    min_filter: Filter = .DEFAULT,
    mag_filter: Filter = .DEFAULT,
    wrap_u: Wrap = .DEFAULT,
    wrap_v: Wrap = .DEFAULT,
    wrap_w: Wrap = .DEFAULT,
    border_color: BorderColor = .DEFAULT,
    max_anisotropy: u32 = 0,
    min_lod: f32 = 0.0,
    max_lod: f32 = 0.0,
    data: ImageData = .{},
    label: [*c]const u8 = null,
    gl_textures: [2]u32 = [_]u32{0} ** 2,
    gl_texture_target: u32 = 0,
    mtl_textures: [2]?*const c_void = [_]?*const c_void{null} ** 2,
    d3d11_texture: ?*const c_void = null,
    d3d11_shader_resource_view: ?*const c_void = null,
    wgpu_texture: ?*const c_void = null,
    _end_canary: u32 = 0,
};
pub const ShaderAttrDesc = extern struct {
    name: [*c]const u8 = null,
    sem_name: [*c]const u8 = null,
    sem_index: i32 = 0,
};
pub const ShaderUniformDesc = extern struct {
    name: [*c]const u8 = null,
    type: UniformType = .INVALID,
    array_count: i32 = 0,
};
pub const ShaderUniformBlockDesc = extern struct {
    size: usize = 0,
    uniforms: [16]ShaderUniformDesc = [_]ShaderUniformDesc{.{}} ** 16,
};
pub const ShaderImageDesc = extern struct {
    name: [*c]const u8 = null,
    image_type: ImageType = .DEFAULT,
    sampler_type: SamplerType = .DEFAULT,
};
pub const ShaderStageDesc = extern struct {
    source: [*c]const u8 = null,
    bytecode: Range = .{},
    entry: [*c]const u8 = null,
    d3d11_target: [*c]const u8 = null,
    uniform_blocks: [4]ShaderUniformBlockDesc = [_]ShaderUniformBlockDesc{.{}} ** 4,
    images: [12]ShaderImageDesc = [_]ShaderImageDesc{.{}} ** 12,
};
pub const ShaderDesc = extern struct {
    _start_canary: u32 = 0,
    attrs: [16]ShaderAttrDesc = [_]ShaderAttrDesc{.{}} ** 16,
    vs: ShaderStageDesc = .{},
    fs: ShaderStageDesc = .{},
    label: [*c]const u8 = null,
    _end_canary: u32 = 0,
};
pub const BufferLayoutDesc = extern struct {
    stride: i32 = 0,
    step_func: VertexStep = .DEFAULT,
    step_rate: i32 = 0,
    __pad: [2]u32 = [_]u32{0} ** 2,
};
pub const VertexAttrDesc = extern struct {
    buffer_index: i32 = 0,
    offset: i32 = 0,
    format: VertexFormat = .INVALID,
    __pad: [2]u32 = [_]u32{0} ** 2,
};
pub const LayoutDesc = extern struct {
    buffers: [8]BufferLayoutDesc = [_]BufferLayoutDesc{.{}} ** 8,
    attrs: [16]VertexAttrDesc = [_]VertexAttrDesc{.{}} ** 16,
};
pub const StencilFaceState = extern struct {
    compare: CompareFunc = .DEFAULT,
    fail_op: StencilOp = .DEFAULT,
    depth_fail_op: StencilOp = .DEFAULT,
    pass_op: StencilOp = .DEFAULT,
};
pub const StencilState = extern struct {
    enabled: bool = false,
    front: StencilFaceState = .{},
    back: StencilFaceState = .{},
    read_mask: u8 = 0,
    write_mask: u8 = 0,
    ref: u8 = 0,
};
pub const DepthState = extern struct {
    pixel_format: PixelFormat = .DEFAULT,
    compare: CompareFunc = .DEFAULT,
    write_enabled: bool = false,
    bias: f32 = 0.0,
    bias_slope_scale: f32 = 0.0,
    bias_clamp: f32 = 0.0,
};
pub const BlendState = extern struct {
    enabled: bool = false,
    src_factor_rgb: BlendFactor = .DEFAULT,
    dst_factor_rgb: BlendFactor = .DEFAULT,
    op_rgb: BlendOp = .DEFAULT,
    src_factor_alpha: BlendFactor = .DEFAULT,
    dst_factor_alpha: BlendFactor = .DEFAULT,
    op_alpha: BlendOp = .DEFAULT,
};
pub const ColorState = extern struct {
    pixel_format: PixelFormat = .DEFAULT,
    write_mask: ColorMask = .DEFAULT,
    blend: BlendState = .{},
};
pub const PipelineDesc = extern struct {
    _start_canary: u32 = 0,
    shader: Shader = .{},
    layout: LayoutDesc = .{},
    depth: DepthState = .{},
    stencil: StencilState = .{},
    color_count: i32 = 0,
    colors: [4]ColorState = [_]ColorState{.{}} ** 4,
    primitive_type: PrimitiveType = .DEFAULT,
    index_type: IndexType = .DEFAULT,
    cull_mode: CullMode = .DEFAULT,
    face_winding: FaceWinding = .DEFAULT,
    sample_count: i32 = 0,
    blend_color: Color = .{},
    alpha_to_coverage_enabled: bool = false,
    label: [*c]const u8 = null,
    _end_canary: u32 = 0,
};
pub const PassAttachmentDesc = extern struct {
    image: Image = .{},
    mip_level: i32 = 0,
    slice: i32 = 0,
};
pub const PassDesc = extern struct {
    _start_canary: u32 = 0,
    color_attachments: [4]PassAttachmentDesc = [_]PassAttachmentDesc{.{}} ** 4,
    depth_stencil_attachment: PassAttachmentDesc = .{},
    label: [*c]const u8 = null,
    _end_canary: u32 = 0,
};
pub const SlotInfo = extern struct {
    state: ResourceState = .INITIAL,
    res_id: u32 = 0,
    ctx_id: u32 = 0,
};
pub const BufferInfo = extern struct {
    slot: SlotInfo = .{},
    update_frame_index: u32 = 0,
    append_frame_index: u32 = 0,
    append_pos: i32 = 0,
    append_overflow: bool = false,
    num_slots: i32 = 0,
    active_slot: i32 = 0,
};
pub const ImageInfo = extern struct {
    slot: SlotInfo = .{},
    upd_frame_index: u32 = 0,
    num_slots: i32 = 0,
    active_slot: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
};
pub const ShaderInfo = extern struct {
    slot: SlotInfo = .{},
};
pub const PipelineInfo = extern struct {
    slot: SlotInfo = .{},
};
pub const PassInfo = extern struct {
    slot: SlotInfo = .{},
};
pub const GlContextDesc = extern struct {
    force_gles2: bool = false,
};
pub const MetalContextDesc = extern struct {
    device: ?*const c_void = null,
    renderpass_descriptor_cb: ?fn () callconv(.C) ?*const c_void = null,
    renderpass_descriptor_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    drawable_cb: ?fn () callconv(.C) ?*const c_void = null,
    drawable_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    user_data: ?*c_void = null,
};
pub const D3d11ContextDesc = extern struct {
    device: ?*const c_void = null,
    device_context: ?*const c_void = null,
    render_target_view_cb: ?fn () callconv(.C) ?*const c_void = null,
    render_target_view_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    depth_stencil_view_cb: ?fn () callconv(.C) ?*const c_void = null,
    depth_stencil_view_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    user_data: ?*c_void = null,
};
pub const WgpuContextDesc = extern struct {
    device: ?*const c_void = null,
    render_view_cb: ?fn () callconv(.C) ?*const c_void = null,
    render_view_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    resolve_view_cb: ?fn () callconv(.C) ?*const c_void = null,
    resolve_view_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    depth_stencil_view_cb: ?fn () callconv(.C) ?*const c_void = null,
    depth_stencil_view_userdata_cb: ?fn (?*c_void) callconv(.C) ?*const c_void = null,
    user_data: ?*c_void = null,
};
pub const ContextDesc = extern struct {
    color_format: i32 = 0,
    depth_format: i32 = 0,
    sample_count: i32 = 0,
    gl: GlContextDesc = .{},
    metal: MetalContextDesc = .{},
    d3d11: D3d11ContextDesc = .{},
    wgpu: WgpuContextDesc = .{},
};
pub const Desc = extern struct {
    _start_canary: u32 = 0,
    buffer_pool_size: i32 = 0,
    image_pool_size: i32 = 0,
    shader_pool_size: i32 = 0,
    pipeline_pool_size: i32 = 0,
    pass_pool_size: i32 = 0,
    context_pool_size: i32 = 0,
    uniform_buffer_size: i32 = 0,
    staging_buffer_size: i32 = 0,
    sampler_cache_size: i32 = 0,
    context: ContextDesc = .{},
    _end_canary: u32 = 0,
};
pub extern fn sg_setup([*c]const Desc) void;
pub fn setup(desc: Desc) void {
    sg_setup(&desc);
}
pub extern fn sg_shutdown() void;
pub fn shutdown() void {
    sg_shutdown();
}
pub extern fn sg_isvalid() bool;
pub fn isvalid() bool {
    return sg_isvalid();
}
pub extern fn sg_reset_state_cache() void;
pub fn resetStateCache() void {
    sg_reset_state_cache();
}
pub extern fn sg_push_debug_group([*c]const u8) void;
pub fn pushDebugGroup(name: [:0]const u8) void {
    sg_push_debug_group(@ptrCast([*c]const u8, name));
}
pub extern fn sg_pop_debug_group() void;
pub fn popDebugGroup() void {
    sg_pop_debug_group();
}
pub extern fn sg_make_buffer([*c]const BufferDesc) Buffer;
pub fn makeBuffer(desc: BufferDesc) Buffer {
    return sg_make_buffer(&desc);
}
pub extern fn sg_make_image([*c]const ImageDesc) Image;
pub fn makeImage(desc: ImageDesc) Image {
    return sg_make_image(&desc);
}
pub extern fn sg_make_shader([*c]const ShaderDesc) Shader;
pub fn makeShader(desc: ShaderDesc) Shader {
    return sg_make_shader(&desc);
}
pub extern fn sg_make_pipeline([*c]const PipelineDesc) Pipeline;
pub fn makePipeline(desc: PipelineDesc) Pipeline {
    return sg_make_pipeline(&desc);
}
pub extern fn sg_make_pass([*c]const PassDesc) Pass;
pub fn makePass(desc: PassDesc) Pass {
    return sg_make_pass(&desc);
}
pub extern fn sg_destroy_buffer(Buffer) void;
pub fn destroyBuffer(buf: Buffer) void {
    sg_destroy_buffer(buf);
}
pub extern fn sg_destroy_image(Image) void;
pub fn destroyImage(img: Image) void {
    sg_destroy_image(img);
}
pub extern fn sg_destroy_shader(Shader) void;
pub fn destroyShader(shd: Shader) void {
    sg_destroy_shader(shd);
}
pub extern fn sg_destroy_pipeline(Pipeline) void;
pub fn destroyPipeline(pip: Pipeline) void {
    sg_destroy_pipeline(pip);
}
pub extern fn sg_destroy_pass(Pass) void;
pub fn destroyPass(pass: Pass) void {
    sg_destroy_pass(pass);
}
pub extern fn sg_update_buffer(Buffer, [*c]const Range) void;
pub fn updateBuffer(buf: Buffer, data: Range) void {
    sg_update_buffer(buf, &data);
}
pub extern fn sg_update_image(Image, [*c]const ImageData) void;
pub fn updateImage(img: Image, data: ImageData) void {
    sg_update_image(img, &data);
}
pub extern fn sg_append_buffer(Buffer, [*c]const Range) i32;
pub fn appendBuffer(buf: Buffer, data: Range) i32 {
    return sg_append_buffer(buf, &data);
}
pub extern fn sg_query_buffer_overflow(Buffer) bool;
pub fn queryBufferOverflow(buf: Buffer) bool {
    return sg_query_buffer_overflow(buf);
}
pub extern fn sg_begin_default_pass([*c]const PassAction, i32, i32) void;
pub fn beginDefaultPass(pass_action: PassAction, width: i32, height: i32) void {
    sg_begin_default_pass(&pass_action, width, height);
}
pub extern fn sg_begin_default_passf([*c]const PassAction, f32, f32) void;
pub fn beginDefaultPassf(pass_action: PassAction, width: f32, height: f32) void {
    sg_begin_default_passf(&pass_action, width, height);
}
pub extern fn sg_begin_pass(Pass, [*c]const PassAction) void;
pub fn beginPass(pass: Pass, pass_action: PassAction) void {
    sg_begin_pass(pass, &pass_action);
}
pub extern fn sg_apply_viewport(i32, i32, i32, i32, bool) void;
pub fn applyViewport(x: i32, y: i32, width: i32, height: i32, origin_top_left: bool) void {
    sg_apply_viewport(x, y, width, height, origin_top_left);
}
pub extern fn sg_apply_viewportf(f32, f32, f32, f32, bool) void;
pub fn applyViewportf(x: f32, y: f32, width: f32, height: f32, origin_top_left: bool) void {
    sg_apply_viewportf(x, y, width, height, origin_top_left);
}
pub extern fn sg_apply_scissor_rect(i32, i32, i32, i32, bool) void;
pub fn applyScissorRect(x: i32, y: i32, width: i32, height: i32, origin_top_left: bool) void {
    sg_apply_scissor_rect(x, y, width, height, origin_top_left);
}
pub extern fn sg_apply_scissor_rectf(f32, f32, f32, f32, bool) void;
pub fn applyScissorRectf(x: f32, y: f32, width: f32, height: f32, origin_top_left: bool) void {
    sg_apply_scissor_rectf(x, y, width, height, origin_top_left);
}
pub extern fn sg_apply_pipeline(Pipeline) void;
pub fn applyPipeline(pip: Pipeline) void {
    sg_apply_pipeline(pip);
}
pub extern fn sg_apply_bindings([*c]const Bindings) void;
pub fn applyBindings(bindings: Bindings) void {
    sg_apply_bindings(&bindings);
}
pub extern fn sg_apply_uniforms(ShaderStage, u32, [*c]const Range) void;
pub fn applyUniforms(stage: ShaderStage, ub_index: u32, data: Range) void {
    sg_apply_uniforms(stage, ub_index, &data);
}
pub extern fn sg_draw(u32, u32, u32) void;
pub fn draw(base_element: u32, num_elements: u32, num_instances: u32) void {
    sg_draw(base_element, num_elements, num_instances);
}
pub extern fn sg_end_pass() void;
pub fn endPass() void {
    sg_end_pass();
}
pub extern fn sg_commit() void;
pub fn commit() void {
    sg_commit();
}
pub extern fn sg_query_desc() Desc;
pub fn queryDesc() Desc {
    return sg_query_desc();
}
pub extern fn sg_query_backend() Backend;
pub fn queryBackend() Backend {
    return sg_query_backend();
}
pub extern fn sg_query_features() Features;
pub fn queryFeatures() Features {
    return sg_query_features();
}
pub extern fn sg_query_limits() Limits;
pub fn queryLimits() Limits {
    return sg_query_limits();
}
pub extern fn sg_query_pixelformat(PixelFormat) PixelformatInfo;
pub fn queryPixelformat(fmt: PixelFormat) PixelformatInfo {
    return sg_query_pixelformat(fmt);
}
pub extern fn sg_query_buffer_state(Buffer) ResourceState;
pub fn queryBufferState(buf: Buffer) ResourceState {
    return sg_query_buffer_state(buf);
}
pub extern fn sg_query_image_state(Image) ResourceState;
pub fn queryImageState(img: Image) ResourceState {
    return sg_query_image_state(img);
}
pub extern fn sg_query_shader_state(Shader) ResourceState;
pub fn queryShaderState(shd: Shader) ResourceState {
    return sg_query_shader_state(shd);
}
pub extern fn sg_query_pipeline_state(Pipeline) ResourceState;
pub fn queryPipelineState(pip: Pipeline) ResourceState {
    return sg_query_pipeline_state(pip);
}
pub extern fn sg_query_pass_state(Pass) ResourceState;
pub fn queryPassState(pass: Pass) ResourceState {
    return sg_query_pass_state(pass);
}
pub extern fn sg_query_buffer_info(Buffer) BufferInfo;
pub fn queryBufferInfo(buf: Buffer) BufferInfo {
    return sg_query_buffer_info(buf);
}
pub extern fn sg_query_image_info(Image) ImageInfo;
pub fn queryImageInfo(img: Image) ImageInfo {
    return sg_query_image_info(img);
}
pub extern fn sg_query_shader_info(Shader) ShaderInfo;
pub fn queryShaderInfo(shd: Shader) ShaderInfo {
    return sg_query_shader_info(shd);
}
pub extern fn sg_query_pipeline_info(Pipeline) PipelineInfo;
pub fn queryPipelineInfo(pip: Pipeline) PipelineInfo {
    return sg_query_pipeline_info(pip);
}
pub extern fn sg_query_pass_info(Pass) PassInfo;
pub fn queryPassInfo(pass: Pass) PassInfo {
    return sg_query_pass_info(pass);
}
pub extern fn sg_query_buffer_defaults([*c]const BufferDesc) BufferDesc;
pub fn queryBufferDefaults(desc: BufferDesc) BufferDesc {
    return sg_query_buffer_defaults(&desc);
}
pub extern fn sg_query_image_defaults([*c]const ImageDesc) ImageDesc;
pub fn queryImageDefaults(desc: ImageDesc) ImageDesc {
    return sg_query_image_defaults(&desc);
}
pub extern fn sg_query_shader_defaults([*c]const ShaderDesc) ShaderDesc;
pub fn queryShaderDefaults(desc: ShaderDesc) ShaderDesc {
    return sg_query_shader_defaults(&desc);
}
pub extern fn sg_query_pipeline_defaults([*c]const PipelineDesc) PipelineDesc;
pub fn queryPipelineDefaults(desc: PipelineDesc) PipelineDesc {
    return sg_query_pipeline_defaults(&desc);
}
pub extern fn sg_query_pass_defaults([*c]const PassDesc) PassDesc;
pub fn queryPassDefaults(desc: PassDesc) PassDesc {
    return sg_query_pass_defaults(&desc);
}
pub extern fn sg_alloc_buffer() Buffer;
pub fn allocBuffer() Buffer {
    return sg_alloc_buffer();
}
pub extern fn sg_alloc_image() Image;
pub fn allocImage() Image {
    return sg_alloc_image();
}
pub extern fn sg_alloc_shader() Shader;
pub fn allocShader() Shader {
    return sg_alloc_shader();
}
pub extern fn sg_alloc_pipeline() Pipeline;
pub fn allocPipeline() Pipeline {
    return sg_alloc_pipeline();
}
pub extern fn sg_alloc_pass() Pass;
pub fn allocPass() Pass {
    return sg_alloc_pass();
}
pub extern fn sg_dealloc_buffer(Buffer) void;
pub fn deallocBuffer(buf_id: Buffer) void {
    sg_dealloc_buffer(buf_id);
}
pub extern fn sg_dealloc_image(Image) void;
pub fn deallocImage(img_id: Image) void {
    sg_dealloc_image(img_id);
}
pub extern fn sg_dealloc_shader(Shader) void;
pub fn deallocShader(shd_id: Shader) void {
    sg_dealloc_shader(shd_id);
}
pub extern fn sg_dealloc_pipeline(Pipeline) void;
pub fn deallocPipeline(pip_id: Pipeline) void {
    sg_dealloc_pipeline(pip_id);
}
pub extern fn sg_dealloc_pass(Pass) void;
pub fn deallocPass(pass_id: Pass) void {
    sg_dealloc_pass(pass_id);
}
pub extern fn sg_init_buffer(Buffer, [*c]const BufferDesc) void;
pub fn initBuffer(buf_id: Buffer, desc: BufferDesc) void {
    sg_init_buffer(buf_id, &desc);
}
pub extern fn sg_init_image(Image, [*c]const ImageDesc) void;
pub fn initImage(img_id: Image, desc: ImageDesc) void {
    sg_init_image(img_id, &desc);
}
pub extern fn sg_init_shader(Shader, [*c]const ShaderDesc) void;
pub fn initShader(shd_id: Shader, desc: ShaderDesc) void {
    sg_init_shader(shd_id, &desc);
}
pub extern fn sg_init_pipeline(Pipeline, [*c]const PipelineDesc) void;
pub fn initPipeline(pip_id: Pipeline, desc: PipelineDesc) void {
    sg_init_pipeline(pip_id, &desc);
}
pub extern fn sg_init_pass(Pass, [*c]const PassDesc) void;
pub fn initPass(pass_id: Pass, desc: PassDesc) void {
    sg_init_pass(pass_id, &desc);
}
pub extern fn sg_uninit_buffer(Buffer) bool;
pub fn uninitBuffer(buf_id: Buffer) bool {
    return sg_uninit_buffer(buf_id);
}
pub extern fn sg_uninit_image(Image) bool;
pub fn uninitImage(img_id: Image) bool {
    return sg_uninit_image(img_id);
}
pub extern fn sg_uninit_shader(Shader) bool;
pub fn uninitShader(shd_id: Shader) bool {
    return sg_uninit_shader(shd_id);
}
pub extern fn sg_uninit_pipeline(Pipeline) bool;
pub fn uninitPipeline(pip_id: Pipeline) bool {
    return sg_uninit_pipeline(pip_id);
}
pub extern fn sg_uninit_pass(Pass) bool;
pub fn uninitPass(pass_id: Pass) bool {
    return sg_uninit_pass(pass_id);
}
pub extern fn sg_fail_buffer(Buffer) void;
pub fn failBuffer(buf_id: Buffer) void {
    sg_fail_buffer(buf_id);
}
pub extern fn sg_fail_image(Image) void;
pub fn failImage(img_id: Image) void {
    sg_fail_image(img_id);
}
pub extern fn sg_fail_shader(Shader) void;
pub fn failShader(shd_id: Shader) void {
    sg_fail_shader(shd_id);
}
pub extern fn sg_fail_pipeline(Pipeline) void;
pub fn failPipeline(pip_id: Pipeline) void {
    sg_fail_pipeline(pip_id);
}
pub extern fn sg_fail_pass(Pass) void;
pub fn failPass(pass_id: Pass) void {
    sg_fail_pass(pass_id);
}
pub extern fn sg_setup_context() Context;
pub fn setupContext() Context {
    return sg_setup_context();
}
pub extern fn sg_activate_context(Context) void;
pub fn activateContext(ctx_id: Context) void {
    sg_activate_context(ctx_id);
}
pub extern fn sg_discard_context(Context) void;
pub fn discardContext(ctx_id: Context) void {
    sg_discard_context(ctx_id);
}
pub extern fn sg_d3d11_device() ?*const c_void;
pub fn d3d11Device() ?*const c_void {
    return sg_d3d11_device();
}
pub extern fn sg_mtl_device() ?*const c_void;
pub fn mtlDevice() ?*const c_void {
    return sg_mtl_device();
}
pub extern fn sg_mtl_render_command_encoder() ?*const c_void;
pub fn mtlRenderCommandEncoder() ?*const c_void {
    return sg_mtl_render_command_encoder();
}
