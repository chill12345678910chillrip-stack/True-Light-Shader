#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"
#include "/lib/water.glsl"

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
flat in float matType;
flat in float blockId;
flat in vec4 emissiveGlow;

/* RENDERTARGETS: 0,2,3 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;
layout(location = 2) out vec4 outColor3;

void main() {
    outColor2 = vec4(0.0);
    outColor3 = vec4(0.0);

    vec4 tex = texture(gtexture, texcoord) * vec4(glcolor.rgb, 1.0);
    if (tex.a < alphaTestRef) discard;
    vec3 albedo = toLinear(tex.rgb);

    if (matType > 1.5 && matType < 2.5) {
        outColor0 = vec4(applyFog(lavaRadiance(albedo, worldPos), viewPos), 1.0);
        return;
    }

    vec3 vnGeom = normalize(normal);
    vec2 L = clamp(lmcoord / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    bool isWater = matType > 0.5 && matType < 1.5;

#if QUALITY == 0
    {
        vec3 lm = toLinear(texture(lightmap, lmcoord).rgb);
        vec3 col = albedo * lm;
        col += emissiveRadiance(emissiveGlow, blockId, tex.rgb);
        outColor0 = vec4(applyFog(col, viewPos), tex.a);
        return;
    }
#else
    vec3 Ldir = normalize(shadowLightPosition);
    vec3 viewDir = normalize(-viewPos);

    float ndlGeom = max(dot(vnGeom, Ldir), 0.0);
    vec3 shadow = getSoftShadowFast(shadowClipPos, gl_FragCoord.xy, ndlGeom, L.y);
    shadow = mix(vec3(1.0), shadow, SHADOW_STRENGTH);
    float sunVis = (luma(shadow) > 0.5 && ndlGeom > 0.05 && !inNether() && !inTheEnd()) ? 1.0 : 0.0;

    if (isWater) {
        vec3 nWorldGeom = mat3(gbufferModelViewInverse) * vnGeom;
        vec3 nWorld = nWorldGeom;
        if (nWorldGeom.y > 0.5) {
            nWorld = waterNormalWorld(worldPos.xz, frameTimeCounter, length(viewPos));
        }
        vec3 nView = normalize(mat3(gbufferModelView) * nWorld);
        if (dot(nView, viewDir) < 0.0) nView = -nView;

        vec3 biome = toLinear(glcolor.rgb);
        vec3 ratio = clamp(biome / vec3(0.05, 0.18, 0.78), vec3(0.2), vec3(3.0));
        vec3 tint = vec3(0.04, 0.30, 0.42) * sqrt(ratio);

        vec3 irradiance = sceneLighting(vnGeom, L, shadow, ndlGeom, 1.0, viewPos);
        vec3 inscatter = tint * irradiance * 0.30;

        outColor0 = vec4(0.0);
        outColor2 = vec4(nView.xy * 0.5 + 0.5, encodeReflectData(L.y, sunVis, 0.02, false, true), 1.0);
        outColor3 = vec4(inscatter, 1.0);
        return;
    }

    float ndl = ndlGeom;
    vec3 col = albedo * sceneLighting(vnGeom, L, shadow, ndl, 1.0, viewPos);
    vec3 emis = emissiveRadiance(emissiveGlow, blockId, tex.rgb);
    if (blockId == 11031.0) emis /= max(tex.a, 0.5);
    col += emis;
    outColor0 = vec4(applyFog(col, viewPos), tex.a);

    if (matType > 2.5) {
        float f0 = matType < 3.5 ? 0.04 : 0.06;
        vec3 nV = vnGeom;
        if (dot(nV, viewDir) < 0.0) nV = -nV;
        outColor2 = vec4(nV.xy * 0.5 + 0.5, encodeReflectData(L.y, sunVis, f0, false, false), 1.0);
    }
#endif
}
