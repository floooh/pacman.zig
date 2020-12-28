
#version 330
uniform sampler2D tile_tex;
uniform sampler2D pal_tex;
in vec2 uv;
in vec4 data;
out vec4 frag_color;
void main() {
    float color_code = data.x;
    float tile_color = texture(tile_tex, uv).x;
    vec2 pal_uv = vec2(color_code * 4 + tile_color, 0);
    frag_color = texture(pal_tex, pal_uv) * vec4(1, 1, 1, data.y);
}