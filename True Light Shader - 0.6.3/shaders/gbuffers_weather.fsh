#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 viewPos;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;

    vec2 L = clamp(lmcoord / (30.0 / 32.0) - (1.0 / 32.0), 0.0, 1.0);
    vec3 light = skyAmbientColor() * (0.5 + 0.9 * L.y) + directLightColor() * (0.12 * L.y);
    light += vec3(1.0, 0.58, 0.27) * (pow(L.x, 3.0) * 1.5);
    vec3 col = toLinear(tex.rgb) * light * 1.4 + vec3(0.03);
    outColor0 = vec4(applyFog(col, viewPos), tex.a);
    outColor2 = vec4(0.0);
}
