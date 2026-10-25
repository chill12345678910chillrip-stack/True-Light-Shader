#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform vec4 entityColor;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
in vec4 shadowClipPos;

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
    float ndl = max(dot(vn, normalize(shadowLightPosition)), 0.0);
    vec3 shadow = getSoftShadowFast(shadowClipPos, gl_FragCoord.xy, ndl, L.y);
    shadow = mix(vec3(1.0), shadow, SHADOW_STRENGTH);
    vec3 col = albedo * sceneLighting(vn, L, shadow, ndl, 1.0, viewPos);
#endif

    col = mix(col, toLinear(entityColor.rgb) * 1.5, entityColor.a);
    outColor0 = vec4(applyFog(col, viewPos), tex.a);
}
