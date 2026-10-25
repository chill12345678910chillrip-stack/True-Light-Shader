#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
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

    vec3 lm = toLinear(texture(lightmap, lmcoord).rgb);
    vec3 col = toLinear(tex.rgb) * lm * 1.35;
    outColor0 = vec4(applyFog(col, viewPos), tex.a);
    outColor2 = vec4(0.0);
}
