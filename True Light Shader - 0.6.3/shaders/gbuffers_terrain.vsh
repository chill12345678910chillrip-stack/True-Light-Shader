#version 330 compatibility

#include "/lib/common.glsl"

in vec3 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
out vec3 worldPos;
out vec4 shadowClipPos;
flat out vec4 emissiveGlow;
flat out float blockId;
flat out vec4 matInfo;

void main() {
    vec4 pos = gl_Vertex;
    float id = mc_Entity.x;
    blockId = id;

    emissiveGlow = emissiveGlowColor(id);

    bool isGrassLike = (id == 11000.0);
    bool isLeavesLike = (id == 11001.0);
    bool isVineLike = (id == 11002.0);

    float f0 = 0.0;
    float metal = 0.0;
#ifdef SHINY_BLOCKS
    if (id == 11040.0) { f0 = 0.55; metal = 1.0; }
    else if (id == 11041.0) { f0 = 0.12; }
    else if (id == 11042.0) { f0 = 0.07; }
    else if (id == 11043.0) { f0 = 0.08; }
#endif
    matInfo = vec4(f0, metal, (isGrassLike || isLeavesLike || isVineLike) ? 1.0 : 0.0, id == 11004.0 ? 1.0 : 0.0);

    if (isGrassLike || isLeavesLike || isVineLike) {
        vec3 restWorldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * pos)).xyz + cameraPosition;

        float topWeight = 0.6;
        if (isGrassLike || isVineLike) {
            topWeight = (gl_MultiTexCoord0.y < mc_midTexCoord.y) ? 1.0 : 0.05;
        }

        float t = frameTimeCounter * 1.4;
        float gust = 0.6 + rainStrength * 0.7;
        float sway = sin(t + restWorldPos.x * 0.6 + restWorldPos.z * 0.6)
                   + sin(t * 1.8 - restWorldPos.x * 1.1 + restWorldPos.z * 0.3) * 0.5;
        sway *= 0.045 * WIND_STRENGTH * gust * topWeight;

        pos.x += sway;
        pos.z += sway * 0.6;
        if (isLeavesLike) {
            pos.y += sway * 0.25;
        }
    }

    vec4 viewPos4 = gl_ModelViewMatrix * pos;
    gl_Position = gl_ProjectionMatrix * viewPos4;
    viewPos = viewPos4.xyz;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    vec3 localNormal = isGrassLike ? vec3(0.0, 1.0, 0.0) : gl_Normal;
    normal = gl_NormalMatrix * localNormal;

    vec3 feetPlayerPos = (gbufferModelViewInverse * viewPos4).xyz;
    worldPos = feetPlayerPos + cameraPosition;

    vec3 worldNormal = mat3(gbufferModelViewInverse) * normalize(normal);
    float ndlV = clamp(dot(normalize(normal), normalize(shadowLightPosition)), 0.0, 1.0);
    float offsetAmt = (0.02 + 0.10 * (1.0 - ndlV)) * (1.0 + length(feetPlayerPos) * 0.02);
    shadowClipPos = shadowProjection * shadowModelView * vec4(feetPlayerPos + worldNormal * offsetAmt, 1.0);
}
