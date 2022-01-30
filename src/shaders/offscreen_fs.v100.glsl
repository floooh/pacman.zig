#version 100
precision mediump float;
uniform sampler2D tile_tex;
uniform sampler2D pal_tex;
varying vec2 uv;
varying vec4 data;
void main() {
    float color_code = data.x;
    float tile_color = texture2D(tile_tex, uv).x;
    vec2 pal_uv = vec2(color_code * 4.0 + tile_color, 0.0);
    gl_FragColor = texture2D(pal_tex, pal_uv) * vec4(1.0, 1.0, 1.0, data.y);
}