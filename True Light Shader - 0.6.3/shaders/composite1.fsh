#version 330 compatibility

#include "/lib/common.glsl"

uniform sampler2D colortex1;

in vec2 texcoord;

/* RENDERTARGETS: 1 */
layout(location = 0) out vec4 outColor0;

void main() {
#if QUALITY == 0
    outColor0 = vec4(0.0);
#else
    float spacing = max(1.0, floor(2.5 * viewHeight / 1080.0 + 0.5));
    vec2 texel = vec2(1.0 / viewWidth, 0.0) * spacing;
    float weights[7] = float[7](0.1371, 0.1297, 0.1097, 0.0831, 0.0563, 0.0341, 0.0185);

    vec3 sum = texture(colortex1, texcoord).rgb * weights[0];
    for (int i = 1; i < 7; i++) {
        sum += texture(colortex1, texcoord + texel * float(i)).rgb * weights[i];
        sum += texture(colortex1, texcoord - texel * float(i)).rgb * weights[i];
    }
    outColor0 = vec4(sum, 1.0);
#endif
}
