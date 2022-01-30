#version 100
attribute vec4 pos;
varying vec2 uv;
void main() {
      gl_Position = vec4((pos.xy - 0.5) * 2.0, 0.0, 1.0);
      uv = pos.xy;
}