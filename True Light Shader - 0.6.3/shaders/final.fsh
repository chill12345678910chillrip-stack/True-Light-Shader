#version 330 compatibility

#include "/lib/common.glsl"

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 outColor0;

vec3 tonemapACES(vec3 x) {
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 hableCurve(vec3 x) {
    float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 tonemapHable(vec3 x) {
    vec3 mapped = hableCurve(x * 2.0) / hableCurve(vec3(11.2));
    return clamp(mapped, 0.0, 1.0);
}

vec3 tonemapSoft(vec3 x) {
    float w = 6.0;
    vec3 m = x * (1.0 + x / (w * w)) / (1.0 + x);
    return clamp(m, 0.0, 1.0);
}

void main() {
    vec3 col = texture(colortex0, texcoord).rgb;

    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    float exposure = EXPOSURE * mix(1.15, 1.0, smoothstep(0.0, 0.5, eyeSky));
    col *= exposure;

#if TONEMAP == 0
    col = tonemapACES(col);
#elif TONEMAP == 1
    col = tonemapHable(col);
#else
    col = tonemapSoft(col);
#endif

    col = toGamma(col);

    float gray = luma(col);
    vec3 cool = vec3(0.97, 0.99, 1.04);
    vec3 warm = vec3(1.04, 1.01, 0.96);
    col *= mix(cool, warm, clamp(gray * 1.2, 0.0, 1.0));

    col = mix(vec3(gray), col, SATURATION);

    col = mix(col, col * col * (3.0 - 2.0 * col), 0.18);

    if (inNether()) {
        col *= vec3(1.04, 0.98, 0.94);
        col = mix(vec3(luma(col)), col, 1.03);
    } else if (inTheEnd()) {
        col *= vec3(0.96, 0.93, 1.05);
    }

    float vignette = 1.0 - VIGNETTE_STRENGTH * pow(length(texcoord - 0.5) * 1.4, 2.2);
    col *= clamp(vignette, 0.0, 1.0);

    float dither = (texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 63, 0).r - 0.5) / 255.0;
    col += dither;

    outColor0 = vec4(clamp(col, 0.0, 1.0), 1.0);
}
