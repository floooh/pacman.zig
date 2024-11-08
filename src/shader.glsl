@vs vs_offscreen
in vec4 in_pos;
in vec2 in_uv;
in vec4 in_data;

out vec2 uv;
out vec4 data;

void main() {
    gl_Position = vec4((in_pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    uv = in_uv;
    data = in_data;
}
@end

@fs fs_offscreen
layout(binding=0) uniform texture2D tile_tex;
layout(binding=1) uniform texture2D pal_tex;
layout(binding=0) uniform sampler smp;

in vec2 uv;
in vec4 data;
out vec4 frag_color;

void main() {
    float color_code = data.x;
    float tile_color = texture(sampler2D(tile_tex, smp), uv).x;
    vec2 pal_uv = vec2(color_code * 4 + tile_color, 0);
    frag_color = texture(sampler2D(pal_tex, smp), pal_uv) * vec4(1, 1, 1, data.y);
}
@end

@program offscreen vs_offscreen fs_offscreen

@vs vs_display
@glsl_options flip_vert_y
in vec4 pos;
out vec2 uv;
void main() {
    gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.0, 1.0);
    uv = pos.xy;
}
@end

@fs fs_display
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec2 uv;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), uv);
}
@end

@program display vs_display fs_display
