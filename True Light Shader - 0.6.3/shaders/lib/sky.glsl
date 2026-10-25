vec3 viewDirFromFrag(vec2 fragCoord) {
    vec4 ndc = vec4(fragCoord / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
    vec4 v = gbufferProjectionInverse * ndc;
    return normalize(v.xyz / v.w);
}

vec3 skyGradient(vec3 dir) {
    vec3 up = normalize(upPosition);
    float h = dot(dir, up);
    float hh = max(h, 0.0);

    vec3 sunDir = normalize(sunPosition);
    float sunH = dot(sunDir, up);
    float cosS = dot(dir, sunDir);
    float day = dayAmount();
    float night = 1.0 - day;

    vec3 zenith = toLinear(skyColor) * vec3(0.40, 0.66, 1.0) * 1.1;
    vec3 horizon = toLinear(fogColor) * vec3(0.90, 0.94, 1.0);

    float g = exp(-hh * 6.5);
    vec3 sky = mix(zenith, horizon, g);
    sky = mix(sky, horizon * 0.35, smoothstep(0.0, 0.4, -h));

    float twi = exp(-16.0 * sunH * sunH);
    float toward = pow(max(cosS * 0.5 + 0.5, 0.0), 4.0);
    float band = exp(-hh * 3.5);
    vec3 twiCol = vec3(1.0, 0.40, 0.16);
    sky += twiCol * (twi * band * (0.10 + 0.90 * toward) * 1.7);

    float sunUp = smoothstep(-0.12, 0.02, sunH);
    float cs = max(cosS, 0.0);
    float mie = pow(cs, 12.0) * 0.30 + pow(cs, 90.0) * 0.70;
    sky += sunRadianceColor() * (mie * sunUp * (1.0 - rainStrength * 0.9));

    vec3 moonDir = normalize(moonPosition);
    float cm = max(dot(dir, moonDir), 0.0);
    float moonUp = smoothstep(-0.12, 0.02, -sunH);
    sky += vec3(0.50, 0.65, 1.00) * ((pow(cm, 24.0) * 0.05 + pow(cm, 300.0) * 0.30) * night * moonUp);
    sky += (vec3(0.010, 0.016, 0.040) + vec3(0.020, 0.025, 0.040) * g) * night;

    float grey = luma(sky);
    sky = mix(sky, vec3(grey) * vec3(0.92, 0.96, 1.0) * 0.85, rainStrength * 0.65);
    return sky;
}

vec3 starField(vec3 dir) {
    float night = 1.0 - dayAmount();
    if (night <= 0.01) return vec3(0.0);

    vec3 wd = mat3(gbufferModelViewInverse) * dir;
    float alpha = 6.2831853 * (sunAngle - 0.25);
    vec3 axis = normalize(vec3(0.0, sin(radians(sunPathRotation)), cos(radians(sunPathRotation))));
    float ca = cos(-alpha);
    float sa = sin(-alpha);
    vec3 p = wd * ca + cross(axis, wd) * sa + axis * dot(axis, wd) * (1.0 - ca);

    vec3 q = p * 115.0;
    vec3 id = floor(q);
    vec3 f = q - id;
    float h = hash13(id);
    if (h > 0.06) return vec3(0.0);
    vec3 center = vec3(hash13(id + 11.1), hash13(id + 23.7), hash13(id + 37.9)) * 0.6 + 0.2;
    float d = length(f - center);
    float r = 0.22;
    float s = 1.0 - smoothstep(0.0, r, d);
    s *= s;
    float br = pow(hash13(id + 5.5), 6.0) * 1.8 + 0.25;
    float twinkle = 0.75 + 0.25 * sin(frameTimeCounter * 4.0 + h * 400.0);
    vec3 starCol = mix(vec3(0.70, 0.82, 1.00), vec3(1.00, 0.86, 0.70), hash13(id + 71.3));

    float above = smoothstep(-0.02, 0.10, dot(dir, normalize(upPosition)));
    return starCol * (s * br * twinkle * 5.0 * night * night * above * (1.0 - rainStrength));
}

const float CLOUD_BASE  = 230.0;
const float CLOUD_THICK = 95.0;
const float CLOUD_SIGMA = 0.075;

float cloudFbm(vec2 p, int octs) {
    float sum = 0.0;
    float amp = 0.5;
    float norm = 0.0;
    for (int i = 0; i < octs; i++) {
        sum += valueNoise(p) * amp;
        norm += amp;
        p = p * 2.03 + vec2(17.1, 9.3);
        amp *= 0.5;
    }
    return sum / norm;
}

float cloudThreshold() {
    return mix(0.50, 0.30, rainStrength) - (CLOUD_COVERAGE - 1.0) * 0.12;
}

float cloudHG(float c, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * c, 1.5);
}

float cloudDensity(vec3 p, float lo, float lod, float eroScale, int shapeOct) {
    float hf = (p.y - CLOUD_BASE) / CLOUD_THICK;
    if (hf <= 0.0 || hf >= 1.0) return 0.0;

    float tm = frameTimeCounter;
    float n = cloudFbm((p.xz + vec2(2.4, 1.0) * tm) * (1.0 / 520.0), shapeOct);
    float f = smoothstep(lo, lo + 0.20, n);
    if (f <= 0.0) return 0.0;

    float topH = 0.22 + 0.78 * pow(f, 0.7);
    float prof = smoothstep(0.0, 0.16, hf) * (1.0 - smoothstep(topH * 0.55, topH, hf));
    float d0 = clamp(f * 1.5, 0.0, 1.0) * prof;
    if (d0 <= 0.0) return 0.0;
    if (eroScale <= 0.0) return d0;

    vec2 e = p.xz + vec2(p.y * 0.35, -p.y * 0.25) + vec2(4.0, 1.6) * tm;
    float er1 = 1.0 - abs(2.0 * valueNoise(e * 0.020) - 1.0);
    float er2 = valueNoise(e * 0.060 + vec2(7.7, 3.1));
    float ero = er1 * 0.6 + er2 * 0.4;
    float k = 0.72 * lod * eroScale;
    return clamp((d0 - ero * k) * (1.0 + 0.5 * k), 0.0, 1.0);
}

bool cloudSlab(vec3 wd, out float t0, out float t1) {
    t0 = 0.0;
    t1 = 0.0;
    float dy = wd.y;
    if (abs(dy) < 0.004) return false;
    float tb = (CLOUD_BASE - cameraPosition.y) / dy;
    float tt = (CLOUD_BASE + CLOUD_THICK - cameraPosition.y) / dy;
    t0 = max(min(tb, tt), 0.0);
    t1 = max(tb, tt);
    const float MAXD = 6000.0;
    if (t1 <= 0.0 || t0 >= MAXD) return false;
    t1 = min(t1, MAXD);
    return true;
}

bool cloudMaybe(vec3 wd, float t0, float t1, float lo) {
    float nmax = 0.0;
    for (int i = 0; i < 4; i++) {
        vec3 p = cameraPosition + wd * mix(t0, t1, float(i) / 3.0);
        nmax = max(nmax, cloudFbm((p.xz + vec2(2.4, 1.0) * frameTimeCounter) * (1.0 / 520.0), 2));
    }
    return nmax >= lo - 0.15;
}

vec4 cloudLayer(vec3 dir, bool detailed) {
    vec3 wd = mat3(gbufferModelViewInverse) * dir;
    float t0, t1;
    if (!cloudSlab(wd, t0, t1)) return vec4(0.0);

    float lo = cloudThreshold();
    if (!cloudMaybe(wd, t0, t1, lo)) return vec4(0.0);

    vec3 lightView = sunHeight() >= 0.0 ? normalize(sunPosition) : normalize(moonPosition);
    vec3 lightWorld = mat3(gbufferModelViewInverse) * lightView;
    float cosL = dot(dir, lightView);
    float phase = mix(cloudHG(cosL, -0.25), cloudHG(cosL, 0.55), 0.55);

    vec3 sunCol = directLightColor();
    sunCol = mix(sunCol, vec3(luma(sunCol)), 0.35);
    vec3 ambSky = skyAmbientColor() * mix(1.0, 0.55, rainStrength);

    vec3 upV = normalize(upPosition);
    vec3 horV = dir - upV * dot(dir, upV);
    float horLen = length(horV);
    vec3 horDir = normalize(horV / max(horLen, 0.001) + upV * 0.03);
    vec3 horCol = skyGradient(horDir);

    float lowAngle = 1.0 - smoothstep(0.08, 0.60, abs(wd.y));
#if QUALITY >= 2
    int steps = int((detailed ? 10.0 + lowAngle * 8.0 : 5.0 + lowAngle * 3.0) + 0.5);
    int shapeOct = detailed ? 5 : 3;
    const int NL = 4;
    const float LMID[4] = float[4](6.0, 20.0, 50.0, 110.0);
    const float LW[4]   = float[4](12.0, 16.0, 40.0, 80.0);
#else
    int steps = int((detailed ? 7.0 + lowAngle * 5.0 : 4.0 + lowAngle * 2.0) + 0.5);
    int shapeOct = detailed ? 4 : 3;
    const int NL = 3;
    const float LMID[3] = float[3](8.0, 30.0, 80.0);
    const float LW[3]   = float[3](16.0, 28.0, 62.0);
#endif
    int nl = detailed ? NL : 2;

    float dt = (t1 - t0) / float(steps);
    float jit = hash12(gl_FragCoord.xy);
    float T = 1.0;
    vec3 R = vec3(0.0);

    for (int i = 0; i < steps; i++) {
        float t = t0 + (float(i) + jit) * dt;
        vec3 p = cameraPosition + wd * t;
        float lod = 1.0 - smoothstep(700.0, 2600.0, t);
        float d = cloudDensity(p, lo, lod, 1.0, shapeOct);
        if (d <= 0.004) continue;

        float hf = clamp((p.y - CLOUD_BASE) / CLOUD_THICK, 0.0, 1.0);

        float od = 0.0;
        for (int k = 0; k < nl; k++) {
            od += cloudDensity(p + lightWorld * LMID[k], lo, lod, k < 2 ? 0.85 : 0.0, max(shapeOct - 2, 2)) * LW[k];
        }
        od *= CLOUD_SIGMA;

        float tSun = exp(-od);
        float tMs = exp(-od * 0.22);
        vec3 sunTerm = sunCol * (phase * tSun + 0.12 * tMs);
        vec3 amb = ambSky * mix(0.16, 1.0, pow(hf, 0.7)) + horCol * ((1.0 - hf) * 0.14);

        float sT = exp(-d * CLOUD_SIGMA * dt);
        R += (T * (1.0 - sT)) * (sunTerm + amb);
        T *= sT;
        if (T < 0.02) break;
    }

    float haze = (1.0 - exp(-t0 * 0.00045)) ;
    float farFade = 1.0 - smoothstep(3500.0, 6000.0, t0);
    float keep = (1.0 - haze) * farFade;
    return vec4(min(R * keep, vec3(8.0)), (1.0 - T) * keep);
}

float cloudTransmittance(vec3 dir) {
    vec3 wd = mat3(gbufferModelViewInverse) * dir;
    float t0, t1;
    if (!cloudSlab(wd, t0, t1)) return 1.0;
    float lo = cloudThreshold();
    if (!cloudMaybe(wd, t0, t1, lo)) return 1.0;

    const int STEPS = 8;
    float dt = (t1 - t0) / float(STEPS);
    float T = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3 p = cameraPosition + wd * (t0 + (float(i) + 0.5) * dt);
        float d = cloudDensity(p, lo, 1.0, 0.6, 3);
        T *= exp(-d * CLOUD_SIGMA * dt);
        if (T < 0.02) break;
    }
    float keep = (1.0 - (1.0 - exp(-t0 * 0.00045))) * (1.0 - smoothstep(3500.0, 6000.0, t0));
    return 1.0 - (1.0 - T) * keep;
}

vec3 skyScene(vec3 dir, bool detailed) {
    vec3 sky = skyGradient(dir);
#if QUALITY >= 1
    if (!inNether() && !inTheEnd()) {
        vec3 st = detailed ? starField(dir) : vec3(0.0);
        vec4 c = cloudLayer(dir, detailed);
        sky = (sky + st) * (1.0 - c.a) + c.rgb;
    }
#endif
    return sky;
}

vec3 fogColorAt(vec3 dir) {
    if (inNether()) {
        vec3 base = toLinear(fogColor);
        float h = dot(dir, normalize(upPosition));
        vec3 top = base * 0.60;
        vec3 low = base * 1.45 + vec3(0.0, base.r * 0.30, 0.0);
        return mix(top, low, 1.0 - smoothstep(-0.5, 0.5, h));
    }
    if (inTheEnd()) return toLinear(fogColor);
    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    float caveMask = mix(0.04, 1.0, smoothstep(0.0, 0.7, eyeSky));
    return skyGradient(dir) * caveMask;
}

vec3 applyFog(vec3 color, vec3 viewPos) {
    if (isEyeInWater != 0) return color;
    float dist = length(viewPos);
    vec3 dir = viewPos / max(dist, 0.0001);
    float sigma = FOG_DENSITY * 0.00055 * (1.0 + rainStrength * 3.5);
    if (inNether()) sigma *= 4.5;
    float f = 1.0 - exp(-dist * sigma);
    f = max(f, smoothstep(0.7 * far, far, dist));
    return mix(color, fogColorAt(dir), clamp(f, 0.0, 1.0));
}
