#version 330 compatibility

#include "/lib/common.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec3 base = texture(colortex0, texcoord).rgb;

#if QUALITY >= 1
    base += texture(colortex1, texcoord).rgb * BLOOM_STRENGTH;

#ifdef GOD_RAYS
    if (isEyeInWater == 0 && !inNether() && !inTheEnd()) {
        float sunH = sunHeight();
        vec3 lightV = sunH >= 0.0 ? sunPosition : moonPosition;
        vec4 lp = gbufferProjection * vec4(lightV, 1.0);
        float strength = smoothstep(-0.02, 0.15, abs(sunH)) * (1.0 - rainStrength * 0.8);
        if (lp.w > 0.0 && strength > 0.001) {
            vec2 lightUV = lp.xy / lp.w * 0.5 + 0.5;
            vec2 toLight = lightUV - texcoord;
            float len = length(toLight);
#if QUALITY >= 2
            const int N = 14;
#else
            const int N = 8;
#endif
            vec2 stepv = toLight / float(N) * 0.85;
            float jitter = shadowDither(gl_FragCoord.xy);
            vec2 pos = texcoord + stepv * jitter;
            float shaft = 0.0;
            float w = 1.0;
            for (int i = 0; i < N; i++) {
                pos += stepv;
                if (pos.x > 0.0 && pos.x < 1.0 && pos.y > 0.0 && pos.y < 1.0) {
                    float d = texelFetch(depthtex0, ivec2(pos * vec2(viewWidth, viewHeight)), 0).r;
                    shaft += (d >= 1.0 ? 1.0 : 0.0) * w;
                }
                w *= 0.94;
            }
            shaft /= float(N);
            float falloff = 1.0 / (1.0 + len * 3.0);
            vec3 rayCol = sunH >= 0.0 ? sunRadianceColor() : vec3(0.25, 0.32, 0.5);
            base += rayCol * (shaft * falloff * strength * 0.20);
        }
    }
#endif
#endif
    outColor0 = vec4(base, 1.0);
}
