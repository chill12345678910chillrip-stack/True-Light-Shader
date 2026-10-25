#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor2;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;
    outColor0 = vec4(applyFog(toLinear(tex.rgb) * 2.5, viewPos), tex.a);
    outColor2 = vec4(0.0);
}
