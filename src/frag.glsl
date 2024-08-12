#version 330 core

in vec3 color;

out vec4 FragColor;

void main() {
    if (color.x <= 0)
        FragColor = vec4(1.0f);
    else
        FragColor = vec4(color, 1.0f);
}