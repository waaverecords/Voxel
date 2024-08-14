#version 460 core

out vec4 FragColor;

uniform sampler2D viewport;

in vec2 UVs;

void main()
{
	FragColor = texture(viewport, UVs);
}