#version 330 compatibility

#include "/lib/common.glsl"

in vec3 mc_Entity;
in vec2 mc_midTexCoord;

out vec2 texcoord;
out vec4 glcolor;

void main() {
    vec4 pos = gl_Vertex;
    float id = mc_Entity.x;

    bool isGrassLike = (id == 11000.0);
    bool isLeavesLike = (id == 11001.0);
    bool isVineLike = (id == 11002.0);

    if (isGrassLike || isLeavesLike || isVineLike) {

        vec3 restWorldPos = (shadowModelViewInverse * (gl_ModelViewMatrix * pos)).xyz + cameraPosition;

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

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;

    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * pos;
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}
