#version 330 compatibility

#include "/lib/common.glsl"

out vec4 glcolor;

void main() {
    gl_Position = ftransform();
    glcolor = gl_Color;
}
