#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;
    outColor2 = vec4(0.0);

    vec3 albedo = toLinear(tex.rgb);

#if QUALITY == 0
    vec3 col = albedo * toLinear(texture(lightmap, lmcoord).rgb);
#else
    vec3 vn = normalize(normal);
    vec2 L = clamp(lmcoord / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float ndl = clamp(dot(vn, normalize(shadowLightPosition)) * 0.5 + 0.5, 0.0, 1.0);
    vec3 col = albedo * sceneLighting(vn, L, vec3(1.0), ndl * ndl, 1.0, viewPos);
#endif

    vec4 g1 = emissiveGlowColor(float(heldItemId));
    vec4 g2 = emissiveGlowColor(float(heldItemId2));
    vec4 glow = g1.a >= g2.a ? g1 : g2;
    if (glow.a > 0.01) {
        float lum = luma(tex.rgb);
        float mask = mix(0.55, 1.0, smoothstep(0.30, 0.65, lum));
        col += glow.rgb * glow.a * mask * 3.2;
    }

    outColor0 = vec4(applyFog(col, viewPos), tex.a);
}
