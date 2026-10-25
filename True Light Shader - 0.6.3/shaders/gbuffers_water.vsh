#version 330 compatibility

#include "/lib/common.glsl"

in vec3 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
out vec3 worldPos;
out vec4 shadowClipPos;
flat out float matType;
flat out float blockId;
flat out vec4 emissiveGlow;

float waterHeight(vec2 p, float t) {
    float h = 0.0;
    h += 0.045 * sin(dot(normalize(vec2(1.0, 0.3)), p) * 0.571 + t * 1.66);
    h += 0.025 * sin(dot(normalize(vec2(0.6, -0.75)), p) * 0.967 + t * 1.27);
    h += 0.013 * sin(dot(normalize(vec2(-0.5, 0.85)), p) * 1.653 + t * 0.975);
    return h;
}

void main() {
    vec4 pos = gl_Vertex;
    float id = mc_Entity.x;
    blockId = id;

    float mt = 0.0;
    if (id == 11003.0) mt = 1.0;
    else if (id == 11004.0) mt = 2.0;
    else if (id == 11005.0) mt = 3.0;
    else if (id == 11006.0) mt = 4.0;
    matType = mt;

    bool isTopSurface = gl_Normal.y > 0.5;
    bool doWave = (mt == 1.0) && isTopSurface && (QUALITY > 0);

    if (doWave) {
        vec3 restWorldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * pos)).xyz + cameraPosition;
        pos.y += waterHeight(restWorldPos.xz, frameTimeCounter) * WATER_WAVE_STRENGTH;
    }
    emissiveGlow = emissiveGlowColor(id);

    vec4 viewPos4 = gl_ModelViewMatrix * pos;
    gl_Position = gl_ProjectionMatrix * viewPos4;
    viewPos = viewPos4.xyz;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    normal = gl_NormalMatrix * gl_Normal;

    vec3 feetPlayerPos = (gbufferModelViewInverse * viewPos4).xyz;
    worldPos = feetPlayerPos + cameraPosition;
    shadowClipPos = shadowProjection * shadowModelView * vec4(feetPlayerPos, 1.0);
}
