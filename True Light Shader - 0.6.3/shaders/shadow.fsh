#version 330 compatibility

#include "/lib/common.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor0;

void main() {
    outColor0 = texture(gtexture, texcoord) * glcolor;
    if (outColor0.a < 0.1) {
        discard;
    }
}
