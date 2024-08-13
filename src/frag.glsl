#version 460 core

in vec3 color;

out vec4 FragColor;

void main() {
    if (color.z >= 0)
        FragColor = vec4(vec3(1.0f), 0.3f);
    else
        FragColor = vec4(color, 1.0f);
}