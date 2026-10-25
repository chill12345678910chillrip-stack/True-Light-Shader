#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

in vec4 glcolor;
in vec3 viewPos;
in vec3 normal;

layout(location = 0) out vec4 outColor0;

void main() {
#if QUALITY >= 1
    discard;
#else
    outColor0 = glcolor;
    if (outColor0.a < 0.02) {
        discard;
    }
    vec3 n = normalize(normal);
    float topShade = clamp(dot(n, normalize(upPosition)) * 0.5 + 0.5, 0.0, 1.0);
    vec3 col = toLinear(outColor0.rgb) * mix(0.70, 1.15, topShade);
    col *= directLightColor() * 0.45 + skyAmbientColor() * 0.9;
    outColor0.rgb = applyFog(col, viewPos);
#endif
}
