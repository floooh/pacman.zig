#version 330
uniform sampler2D tex;
in vec2 uv;
out vec4 frag_color;
void main() {
    frag_color = texture(tex, uv);
}
