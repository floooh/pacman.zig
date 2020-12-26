#version 330
layout(location=0) in vec4 pos;
layout(location=1) in vec2 uv_in;
layout(location=2) in vec4 data_in;
out vec2 uv;
out vec4 data;
void main() {
    gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    uv = uv_in;
    data = data_in;
}
