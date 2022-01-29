#version 300 es
in vec4 pos;
in vec2 uv_in;
in vec4 data_in;
out vec2 uv;
out vec4 data;
void main() {
    gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    uv = uv_in;
    data = data_in;
}
