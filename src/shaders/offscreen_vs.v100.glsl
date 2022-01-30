#version 100
attribute vec4 pos;
attribute vec2 uv_in;
attribute vec4 data_in;
varying vec2 uv;
varying vec4 data;
void main() {
    gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    uv = uv_in;
    data = data_in;
}
