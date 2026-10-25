#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;

layout(location = 0) out vec4 outColor0;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    vec3 lin = toLinear(tex.rgb);
    float a = tex.a;

    if (inTheEnd()) {
        outColor0 = vec4(lin * 0.9, a);
        return;
    }

    vec3 dir = normalize(viewPos);
    bool isSun = dot(dir, normalize(sunPosition)) > dot(dir, normalize(moonPosition));

    vec3 col;
    if (isSun) {
        col = lin * sunRadianceColor() * (SUN_DISC_RADIANCE * (1.0 - rainStrength * 0.92));
    } else {
        col = lin * vec3(0.75, 0.85, 1.05) * (2.2 * (1.0 - rainStrength * 0.9));
    }
#if QUALITY >= 1
    col *= cloudTransmittance(dir);
#endif
    outColor0 = vec4(col, a);
}
