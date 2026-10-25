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
in vec3 worldPos;
in vec4 shadowClipPos;
flat in vec4 emissiveGlow;
flat in float blockId;
flat in vec4 matInfo;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < alphaTestRef) discard;

    vec3 rawTexColor = tex.rgb;
    vec3 albedo = toLinear(tex.rgb * glcolor.rgb);
    outColor2 = vec4(0.0);

    if (matInfo.w > 0.5) {
        outColor0 = vec4(applyFog(lavaRadiance(albedo, worldPos), viewPos), 1.0);
        return;
    }

#if QUALITY == 0
    vec3 lm = toLinear(texture(lightmap, lmcoord).rgb);
    outColor0 = vec4(applyFog(albedo * lm + emissiveRadiance(emissiveGlow, blockId, rawTexColor), viewPos), 1.0);
    return;
#else
    vec3 vn = normalize(normal);
    vec2 L = clamp(lmcoord / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    float ao = glcolor.a;
    bool foliage = matInfo.z > 0.5;

    float f0 = matInfo.x;
    bool metal = matInfo.y > 0.5;
#ifdef WET_SURFACES
    if (wetness > 0.01 && !foliage && !inNether() && !inTheEnd()) {
        float upDot = dot(vn, normalize(upPosition));
        float open = smoothstep(0.80, 1.0, L.y);
        float wetAmt = wetness * open;
        float puddle = smoothstep(0.38, 0.66, valueNoise(worldPos.xz * 0.30) * 0.7 + valueNoise(worldPos.xz * 0.9) * 0.3);
        float surf = wetAmt * smoothstep(0.55, 0.9, upDot);
        albedo *= 1.0 - 0.30 * wetAmt - 0.25 * surf * puddle;
        f0 = max(f0, surf * (0.02 + 0.07 * puddle));
    }
#endif

    vec3 Ldir = normalize(shadowLightPosition);
    float ndlRaw = dot(vn, Ldir);
    float ndl = max(ndlRaw, 0.0);
    if (foliage) {
        ndl = clamp((ndlRaw + 0.45) / 1.45, 0.0, 1.0);
    }

    vec3 shadow = getSoftShadowFast(shadowClipPos, gl_FragCoord.xy, ndl, L.y);
    shadow = mix(vec3(1.0), shadow, SHADOW_STRENGTH);

    vec3 light = sceneLighting(vn, L, shadow, ndl, ao, viewPos);
    vec3 col = albedo * light;
    if (foliage) {
        float back = clamp(-ndlRaw, 0.0, 1.0);
        col += albedo * albedo * directLightColor() * (back * 0.9 * shadow.g * smoothstep(0.2, 0.9, L.y));
    }

    col += emissiveRadiance(emissiveGlow, blockId, rawTexColor);

    outColor0 = vec4(applyFog(col, viewPos), 1.0);

    if (f0 > 0.004) {
        float sunVis = (luma(shadow) > 0.5 && ndl > 0.05 && !inNether() && !inTheEnd()) ? 1.0 : 0.0;
        outColor2 = vec4(vn.xy * 0.5 + 0.5, encodeReflectData(L.y, sunVis, f0, metal, false), 1.0);
    }
#endif
}
