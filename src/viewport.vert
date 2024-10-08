#version 460 core

layout (location = 0) in vec3 vertex;
layout (location = 1) in vec2 uvs;

out vec2 UVs;

void main()
{
	gl_Position = vec4(vertex, 1.0);
	UVs = uvs;
}