#version 330 compatibility

#include "/lib/common.glsl"

in vec4 glcolor;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;

void main() {
    outColor0 = vec4(toLinear(glcolor.rgb), glcolor.a);
    outColor2 = vec4(0.0);
}
