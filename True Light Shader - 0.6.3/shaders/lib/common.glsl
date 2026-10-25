#define QUALITY 1 // [0 1 2]

#define SHADOW_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0]
#define COLORED_SHADOWS
#define SUN_INTENSITY 1.0 // [0.6 0.8 1.0 1.2 1.5]
#define AMBIENT_LIGHT 0.05 // [0.0 0.02 0.05 0.08 0.12]
#define HAND_LIGHT
#define ORE_GLOW
#define LIGHT_SOURCE_GLOW
#define SHINY_BLOCKS
#define WET_SURFACES
#define WIND_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]

#define REFLECTIONS
#define WATER_WAVE_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define WATER_ABSORPTION 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WATER_CAUSTICS
#define RAIN_RIPPLES

#define CLOUD_COVERAGE 1.0 // [0.6 0.8 1.0 1.2 1.4]
#define FOG_DENSITY 2.4 // [1.0 1.6 2.0 2.4 3.2 4.0]

#define EXPOSURE 0.9 // [0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.4 1.6]
#define TONEMAP 0 // [0 1 2]
#define SATURATION 1.1 // [0.8 0.9 1.0 1.1 1.2 1.3 1.4]
#define BLOOM_STRENGTH 0.5 // [0.0 0.15 0.3 0.5 0.75 1.0 1.4]
#define GOD_RAYS
#define VIGNETTE_STRENGTH 0.30 // [0.0 0.15 0.3 0.45 0.6]

#define BLOOM_THRESHOLD 1.2
#define SUN_DISC_RADIANCE 12.0

#if QUALITY == 0
const int shadowMapResolution = 1024;
const float shadowDistanceRenderMul = 0.4;
#elif QUALITY == 1
const int shadowMapResolution = 2048;
const float shadowDistanceRenderMul = 0.6;
#else
const int shadowMapResolution = 3072;
const float shadowDistanceRenderMul = 0.9;
#endif
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const float sunPathRotation = -20.0;

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = R11F_G11F_B10F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
*/
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

uniform sampler2D noisetex;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform float sunAngle;
uniform float shadowAngle;
uniform float rainStrength;
uniform float wetness;
uniform float nightVision;
uniform int worldTime;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;

uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float eyeAltitude;
uniform int biome_category;

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 toLinear(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 toGamma(vec3 c) {
    return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 noised(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;
    float v = a + k1 * u.x + k2 * u.y + k4 * u.x * u.y;
    vec2 dv = du * vec2(k1 + k4 * u.y, k2 + k4 * u.x);
    return vec3(v, dv);
}

bool inNether() {
    return biome_category == 16;
}

bool inTheEnd() {
    return biome_category == 8;
}

float sunHeight() {
    return dot(normalize(sunPosition), normalize(upPosition));
}

float dayAmount() {
    return smoothstep(-0.10, 0.22, sunHeight());
}

vec3 sunRadianceColor() {
    float h = sunHeight();
    vec3 horizonCol = vec3(1.00, 0.42, 0.14);
    vec3 middayCol = vec3(1.00, 0.90, 0.76);
    return mix(horizonCol, middayCol, smoothstep(0.0, 0.45, h));
}

vec3 directLightColor() {
    float h = sunHeight();
    float sunI = smoothstep(-0.015, 0.10, h);
    float moonI = smoothstep(-0.015, 0.10, -h);
    vec3 sun = sunRadianceColor() * (2.1 * SUN_INTENSITY) * sunI;
    vec3 moon = vec3(0.50, 0.65, 1.00) * 0.32 * moonI;
    return (sun + moon) * (1.0 - rainStrength * 0.85);
}

vec3 skyAmbientColor() {
    vec3 zen = toLinear(skyColor);
    vec3 hor = toLinear(fogColor);
    vec3 a = mix(hor, zen, 0.7);
    a = mix(a, vec3(luma(a)), 0.50) * 1.25;
    a += vec3(0.030, 0.045, 0.090) * (1.0 - dayAmount());
    return a;
}

vec3 netherAmbientColor() {
    vec3 warm = vec3(0.60, 0.33, 0.22);
    float tot = max(fogColor.r + fogColor.g + fogColor.b, 0.001);
    float notRed = 1.0 - smoothstep(0.30, 0.60, fogColor.r / tot);
    vec3 tint = mix(vec3(1.0), fogColor / max(luma(fogColor), 0.01), 0.6) * 0.38;
    return mix(warm, tint, notRed);
}

bool isOreGlowId(float id) {
    return id >= 11010.0 && id <= 11019.0;
}

float oreFleckMask(vec3 texColor) {
    float maxC = max(max(texColor.r, texColor.g), texColor.b);
    float minC = min(min(texColor.r, texColor.g), texColor.b);
    float sat = maxC > 0.02 ? (maxC - minC) / maxC : 0.0;
    float bright = luma(texColor);
    float darkSignal = 1.0 - smoothstep(0.05, 0.22, bright);
    float satSignal = smoothstep(0.18, 0.4, sat);
    return clamp(max(darkSignal * 0.6, satSignal), 0.0, 1.0);
}

vec4 emissiveGlowColor(float id) {
#ifdef ORE_GLOW
    if (id == 11010.0) return vec4(0.4, 0.85, 1.0, 1.0);
    if (id == 11011.0) return vec4(1.0, 0.82, 0.25, 1.0);
    if (id == 11012.0) return vec4(1.0, 0.15, 0.1, 1.0);
    if (id == 11013.0) return vec4(0.2, 1.0, 0.5, 1.0);
    if (id == 11014.0) return vec4(0.2, 0.35, 1.0, 1.0);
    if (id == 11015.0) return vec4(0.95, 0.75, 0.55, 0.6);
    if (id == 11016.0) return vec4(1.0, 0.5, 0.25, 0.6);
    if (id == 11017.0) return vec4(0.5, 0.5, 0.5, 0.35);
    if (id == 11018.0) return vec4(0.9, 0.85, 0.75, 0.7);
    if (id == 11019.0) return vec4(0.85, 0.5, 0.85, 0.9);
#endif
#ifdef LIGHT_SOURCE_GLOW
    if (id == 11020.0) return vec4(1.0, 0.55, 0.2, 1.0);
    if (id == 11021.0) return vec4(0.3, 0.8, 1.0, 1.0);
    if (id == 11022.0) return vec4(1.0, 0.1, 0.08, 1.0);
    if (id == 11023.0) return vec4(1.0, 0.8, 0.5, 1.0);
    if (id == 11024.0) return vec4(0.5, 0.8, 1.0, 1.0);
    if (id == 11025.0) return vec4(1.0, 0.9, 0.6, 1.0);
    if (id == 11026.0) return vec4(0.6, 0.95, 0.95, 1.0);
    if (id == 11027.0) return vec4(1.0, 0.55, 0.15, 1.0);
    if (id == 11028.0) return vec4(1.0, 0.5, 0.35, 1.0);
    if (id == 11029.0) return vec4(1.0, 1.0, 0.95, 1.0);
    if (id == 11030.0) return vec4(1.0, 0.85, 0.5, 1.0);
    if (id == 11031.0) return vec4(0.06, 0.007, 0.50, 1.0);
    if (id == 11032.0) return vec4(0.35, 1.0, 0.85, 1.0);
    if (id == 11033.0) return vec4(0.6, 0.35, 0.9, 0.5);
#endif
    return vec4(0.0);
}

vec3 emissiveRadiance(vec4 glow, float id, vec3 rawTex) {
    if (glow.a < 0.01) return vec3(0.0);
    if (isOreGlowId(id)) {
        return glow.rgb * glow.a * oreFleckMask(rawTex) * 1.6;
    }
    float lum = luma(rawTex);
    bool pointLight = (id >= 11020.0 && id <= 11022.0) || id == 11029.0;
    float baseline = pointLight ? 0.10 : 0.55;
    float mask = mix(baseline, 1.0, smoothstep(0.30, 0.65, lum));
    return glow.rgb * glow.a * mask * 4.0;
}

vec3 lavaRadiance(vec3 albedoLin, vec3 worldPos) {
    float t = frameTimeCounter;
    float n = valueNoise(worldPos.xz * 0.70 + vec2(t * 0.10, -t * 0.07)) * 0.55
            + valueNoise(vec2(worldPos.x + worldPos.z, worldPos.y) * 0.70 + vec2(-t * 0.08, t * 0.12)) * 0.45;
    float heat = smoothstep(0.25, 0.75, n);
    float pulse = 0.95 + 0.05 * sin(t * 1.3 + n * 6.2831853);

    vec3 soft = mix(albedoLin, vec3(1.0, 0.33, 0.02), 0.30);

    vec3 tint = mix(vec3(3.2, 0.62, 0.10), vec3(3.8, 1.25, 0.30), heat);
    return soft * tint * pulse;
}

vec3 handLightContribution(vec3 vn, vec3 viewPos) {
#ifdef HAND_LIGHT
    int held = max(heldBlockLightValue, heldBlockLightValue2);
    if (held <= 0) return vec3(0.0);

    float strength = float(held) / 15.0;
    float dist = length(viewPos);
    float radius = mix(4.0, 14.0, strength);
    float t = clamp(1.0 - dist / radius, 0.0, 1.0);
    float atten = t * t;
    vec3 toCam = -viewPos / max(dist, 0.001);
    float facing = clamp(dot(vn, toCam) * 0.6 + 0.4, 0.0, 1.0);

    vec4 g1 = emissiveGlowColor(float(heldItemId));
    vec4 g2 = emissiveGlowColor(float(heldItemId2));
    vec3 tint = g1.a >= g2.a ? g1.rgb : g2.rgb;
    if (g1.a < 0.01 && g2.a < 0.01) {
        tint = vec3(1.0, 0.72, 0.42);
    }
    return tint * (atten * facing * strength * 1.8);
#else
    return vec3(0.0);
#endif
}

vec3 sceneLighting(vec3 vn, vec2 L, vec3 shadow, float ndl, float ao, vec3 viewPos) {
    float upDot = dot(vn, normalize(upPosition));
    float skyL = L.y * L.y;
    vec3 light;

    if (inNether()) {
        float wy = (gbufferModelViewInverse * vec4(viewPos, 1.0)).y + cameraPosition.y;
        float lavaSea = 1.0 - smoothstep(32.0, 100.0, wy);
        vec3 heightTint = mix(vec3(0.82), vec3(1.25, 1.08, 0.88), lavaSea);
        light = netherAmbientColor() * heightTint * (0.75 + 0.25 * upDot) * ao;
        light += vec3(0.50, 0.20, 0.06) * (max(-upDot, 0.0) * lavaSea * ao);
    } else if (inTheEnd()) {
        light = vec3(0.34, 0.28, 0.52) * (0.80 + 0.20 * upDot) * ao;
    } else {
        vec3 sky = skyAmbientColor();
        vec3 ground = sky * vec3(0.62, 0.56, 0.46) * 0.5;
        light = mix(ground, sky, upDot * 0.5 + 0.5) * (skyL * ao);

        float directMask = smoothstep(0.2, 0.9, L.y);
        light += directLightColor() * (ndl * directMask) * shadow;
    }

    light += vec3(1.0, 0.58, 0.27) * (pow(L.x, 3.0) * 2.8);
    light += handLightContribution(vn, viewPos);
    light = max(light, vec3(AMBIENT_LIGHT) * vec3(0.8, 0.9, 1.15) + vec3(nightVision * 0.35));
    return light;
}

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy) + 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

float shadowDither(vec2 fragCoord) {
    ivec2 c = ivec2(fragCoord) & 63;
    return texelFetch(noisetex, c, 0).r;
}

vec3 shadowTap(vec4 shadowClipPos, int i, int samples, float phi, float pcfRadius, float bias, out float lit) {
    float r = sqrt((float(i) + 0.5) / float(samples));
    float theta = float(i) * 2.39996323 + phi;
    vec2 offset = r * vec2(cos(theta), sin(theta)) * pcfRadius;

    vec4 pos = shadowClipPos;
    pos.xy += offset * pos.w;
    pos.z -= bias * pos.w;
    pos.xyz = distortShadowClipPos(pos.xyz);
    vec3 ndc = pos.xyz / pos.w;
    vec3 screenPos = ndc * 0.5 + 0.5;

    lit = 0.0;
    float allLit = step(screenPos.z, texture(shadowtex0, screenPos.xy).r);
    if (allLit == 1.0) {
        lit = 1.0;
        return vec3(1.0);
    }
    float opaqueLit = step(screenPos.z, texture(shadowtex1, screenPos.xy).r);
    if (opaqueLit == 0.0) {
        return vec3(0.0);
    }
#ifdef COLORED_SHADOWS
    lit = 0.5;
    vec4 sc = texture(shadowcolor0, screenPos.xy);
    return toLinear(sc.rgb) * (1.0 - sc.a);
#else
    return vec3(0.0);
#endif
}

vec3 getSoftShadow(vec4 shadowClipPos, vec2 fragCoord, float ndl) {
    float phi = shadowDither(fragCoord) * radians(360.0);

#if QUALITY >= 2
    const int samples = 16;
    const float pcfRadius = 0.0040;
#else
    const int samples = 10;
    const float pcfRadius = 0.0035;
#endif
    float bias = 0.0010 + 0.0022 * (1.0 - clamp(ndl, 0.0, 1.0));

    vec3 accum = vec3(0.0);
    float kindSum = 0.0;
    float lit;

    for (int k = 0; k < 4; k++) {
        int i = (k * (samples - 1)) / 3;
        accum += shadowTap(shadowClipPos, i, samples, phi, pcfRadius, bias, lit);
        kindSum += lit;
    }
    if (kindSum == 4.0) return vec3(1.0);
    if (kindSum == 0.0) return vec3(0.0);

    for (int i = 0; i < samples; i++) {
        if ((i * 3) % (samples - 1) == 0) continue;
        accum += shadowTap(shadowClipPos, i, samples, phi, pcfRadius, bias, lit);
    }
    return accum / float(samples);
}

vec3 getSoftShadowFast(vec4 shadowClipPos, vec2 fragCoord, float ndl, float skyLight) {
#if QUALITY == 0
    return vec3(1.0);
#else
    if (inNether() || inTheEnd()) {
        return vec3(1.0);
    }
    if (ndl <= 0.001 || skyLight <= 0.03) {
        return vec3(1.0);
    }
    return getSoftShadow(shadowClipPos, fragCoord, ndl);
#endif
}

float encodeReflectData(float skyL, float sunVis, float f0, bool metal, bool water) {
    int sl = int(clamp(skyL, 0.0, 1.0) * 15.0 + 0.5);
    int fq = int(sqrt(clamp(f0, 0.0, 1.0)) * 15.0 + 0.5);
    int code = sl + fq * 16;
    if (metal) code += 256;
    if (water) code += 512;
    if (sunVis > 0.5) code += 1024;
    return float(code) / 2048.0;
}
