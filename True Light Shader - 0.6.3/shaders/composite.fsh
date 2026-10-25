#version 330 compatibility

#include "/lib/common.glsl"
#include "/lib/sky.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

in vec2 texcoord;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;

vec3 screenToView(vec2 uv, float depth) {
    vec4 p = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return p.xyz / p.w;
}

vec3 viewToScreen(vec3 v) {
    vec4 p = gbufferProjection * vec4(v, 1.0);
    return (p.xyz / p.w) * 0.5 + 0.5;
}

float linearDepth(float d) {
    return 2.0 * near * far / (far + near - (d * 2.0 - 1.0) * (far - near));
}

#if QUALITY >= 1
#ifdef REFLECTIONS
bool traceSSR(vec3 origin, vec3 dir, float jitter, out vec2 hitUV) {
#if QUALITY >= 2
    const int STEPS = 28;
    const float GROWTH = 1.18;
#else
    const int STEPS = 16;
    const float GROWTH = 1.30;
#endif
    vec2 res = vec2(viewWidth, viewHeight);
    float stepLen = 0.30;
    vec3 prev = origin;
    vec3 pos = origin + dir * (stepLen * jitter);
    hitUV = vec2(0.0);

    for (int i = 0; i < STEPS; i++) {
        prev = pos;
        pos += dir * stepLen;
        stepLen *= GROWTH;
        if (pos.z > -near) return false;

        vec3 sp = viewToScreen(pos);
        if (sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) return false;

        float sceneD = texelFetch(depthtex1, ivec2(sp.xy * res), 0).r;
        if (sceneD >= 1.0) continue;
        float diff = -pos.z - linearDepth(sceneD);
        if (diff > 0.0 && diff < stepLen * 1.5 + 0.15) {
            vec3 a = prev;
            vec3 b = pos;
            for (int j = 0; j < 4; j++) {
                vec3 m = (a + b) * 0.5;
                vec3 sm = viewToScreen(m);
                float md = texelFetch(depthtex1, ivec2(clamp(sm.xy, 0.0, 0.999) * res), 0).r;
                if (-m.z > linearDepth(md)) b = m; else a = m;
            }
            hitUV = viewToScreen(b).xy;
            return true;
        }
    }
    return false;
}
#endif

float causticPattern(vec2 p, float t) {
    float a = valueNoise(p * 1.7 + vec2(t * 0.35, t * 0.22));
    float b = valueNoise(p * 1.9 + vec2(-t * 0.28, t * 0.31) + 5.2);
    float c = clamp(1.0 - abs(a - b) * 3.2, 0.0, 1.0);
    return pow(c, 5.0);
}
#endif

void main() {
    ivec2 px = ivec2(gl_FragCoord.xy);
    vec2 uv = texcoord;
    vec2 res = vec2(viewWidth, viewHeight);

    float depth0 = texelFetch(depthtex0, px, 0).r;
    float depth1 = texelFetch(depthtex1, px, 0).r;

    vec2 sampleUV = uv;
    if (isEyeInWater == 1) {
        sampleUV += vec2(sin(uv.y * 40.0 + frameTimeCounter * 2.0), cos(uv.x * 40.0 + frameTimeCounter * 2.0)) * 0.003;
    }
    vec3 color = texture(colortex0, sampleUV).rgb;

#if QUALITY >= 1
    vec4 data2 = texelFetch(colortex2, px, 0);
    bool underWaterView = (isEyeInWater == 1);

    if (data2.a > 0.5 && depth0 < 1.0) {
        int code = int(data2.b * 2048.0 + 0.5);
        float skyL = float(code & 15) / 15.0;
        float fq = float((code >> 4) & 15) / 15.0;
        float F0 = fq * fq;
        bool metal = (code & 256) != 0;
        bool water = (code & 512) != 0;
        float sunVis = ((code & 1024) != 0) ? 1.0 : 0.0;

        vec2 nxy = data2.rg * 2.0 - 1.0;
        vec3 N = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
        vec3 viewP = screenToView(uv, depth0);
        vec3 V = -normalize(viewP);

        if (!(water && underWaterView)) {

            if (water) {
                vec3 viewB = screenToView(uv, depth1);
                float thickness = (depth1 >= 1.0) ? 64.0 : min(length(viewB - viewP), 64.0);

                vec2 rOff = N.xy * 0.045 * clamp(thickness * 0.35, 0.0, 1.0) / (1.0 + length(viewP) * 0.06);
                vec2 ruv = clamp(uv + rOff, vec2(0.002), vec2(0.998));
                float rd1 = texelFetch(depthtex1, ivec2(ruv * res), 0).r;
                if (rd1 < depth0) ruv = uv;
                vec3 bg = texture(colortex0, ruv).rgb;

                vec3 dl = directLightColor();
#ifdef WATER_CAUSTICS
                if (depth1 < 1.0) {
                    vec3 worldB = (gbufferModelViewInverse * vec4(viewB, 1.0)).xyz + cameraPosition;
                    float c = causticPattern(worldB.xz, frameTimeCounter);
                    float vis = sunVis * smoothstep(0.5, 1.0, skyL) * (luma(dl) / 2.1);
                    bg *= 1.0 + c * 1.8 * vis * exp(-thickness * 0.15);
                }
#endif
                vec3 absorb = vec3(0.32, 0.09, 0.05) * WATER_ABSORPTION;
                vec3 T = exp(-absorb * thickness);
                vec3 inscatter = texelFetch(colortex3, px, 0).rgb;
                color = bg * T + inscatter * (vec3(1.0) - T);

                float foamMask = (1.0 - smoothstep(0.0, 0.55, thickness)) * (depth1 < 1.0 ? 1.0 : 0.0);
                if (foamMask > 0.01) {
                    vec3 wp = (gbufferModelViewInverse * vec4(viewP, 1.0)).xyz + cameraPosition;
                    float fn = valueNoise(wp.xz * 3.0 + frameTimeCounter * 0.4) * 0.6
                             + valueNoise(wp.xz * 7.0 - frameTimeCounter * 0.3) * 0.4;
                    float foam = foamMask * smoothstep(0.35, 0.70, fn + foamMask * 0.35);
                    vec3 foamCol = (skyAmbientColor() * (skyL * skyL) + dl * (0.7 * sunVis)) * 0.8;
                    color = mix(color, foamCol, clamp(foam, 0.0, 1.0) * 0.8);
                }
            }

            float cosT = clamp(dot(N, V), 0.0, 1.0);
            float fres = min(F0 + (1.0 - F0) * pow(1.0 - cosT, 5.0), 0.96);
            vec3 R = reflect(-V, N);

            float occ = smoothstep(0.1, 0.95, skyL);
            vec3 refl = mix(skyAmbientColor() * 0.08, skyScene(R, false), occ);

#ifdef REFLECTIONS
            float ssrW = smoothstep(0.03, 0.09, fres);
            if (ssrW > 0.0) {
                vec2 hitUV;
                float jitter = hash12(gl_FragCoord.xy);
                if (traceSSR(viewP + N * 0.03, R, jitter, hitUV)) {
                    vec3 hitCol = min(texture(colortex0, hitUV).rgb, vec3(30.0));
                    vec2 e = smoothstep(vec2(0.0), vec2(0.10), hitUV) * (1.0 - smoothstep(vec2(0.90), vec2(1.0), hitUV));
                    refl = mix(refl, hitCol, e.x * e.y * ssrW);
                }
            }
#endif

            vec3 Ld = normalize(shadowLightPosition);
            float lc = max(dot(R, Ld), 0.0);
            float glintN = water ? 2400.0 : 300.0;
            float glintAmp = water ? 8.0 : 1.6;
            vec3 glint = directLightColor() * (glintAmp * pow(lc, glintN) * sunVis * smoothstep(0.5, 1.0, skyL));

            if (metal) {
                vec3 tint = clamp(color / max(luma(color), 0.02), vec3(0.0), vec3(2.5));
                tint = mix(vec3(1.0), tint, 0.9);
                color = mix(color * 0.30, refl * tint, fres) + glint * tint;
            } else {
                color = mix(color, refl, fres) + glint * (0.35 + 0.65 * fres);
            }
        }
    }
#endif

    if (isEyeInWater == 1) {
        float dist = (depth1 >= 1.0) ? 64.0 : length(screenToView(uv, depth1));
        float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
        vec3 uwCol = vec3(0.025, 0.17, 0.23) * (0.12 + 0.88 * dayAmount()) * mix(0.25, 1.0, eyeSky);
        vec3 T = exp(-dist * vec3(0.30, 0.075, 0.045));
        color = color * T + uwCol * (vec3(1.0) - T);
    } else if (isEyeInWater == 2) {
        color = mix(color, vec3(1.4, 0.40, 0.06), 0.65);
    }

    outColor0 = vec4(color, 1.0);

#if QUALITY == 0
    outColor1 = vec4(0.0);
#else
    float l = luma(color);
    vec3 bright = color * (max(l - BLOOM_THRESHOLD, 0.0) / max(l, 0.0001));
    outColor1 = vec4(min(bright, vec3(40.0)), 1.0);
#endif
}
