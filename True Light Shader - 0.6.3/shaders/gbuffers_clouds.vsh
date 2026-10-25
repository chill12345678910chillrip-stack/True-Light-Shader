#version 330 compatibility

#include "/lib/common.glsl"

out vec4 glcolor;
out vec3 viewPos;
out vec3 normal;

void main() {
    gl_Position = ftransform();
    glcolor = gl_Color;
    vec4 viewPos4 = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewPos4.xyz;
    normal = gl_NormalMatrix * gl_Normal;
}
