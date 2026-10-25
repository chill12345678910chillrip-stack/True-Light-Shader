#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

in vec4 glcolor;

layout(location = 0) out vec4 outColor0;

void main() {
    vec3 dir = viewDirFromFrag(gl_FragCoord.xy);
    vec3 col;

    if (inNether()) {
        col = fogColorAt(dir);
    } else if (inTheEnd()) {
        col = toLinear(glcolor.rgb) * vec3(0.85, 0.75, 1.05) * 0.8;
    } else {
        col = skyScene(dir, true);
    }
    outColor0 = vec4(col, 1.0);
}
