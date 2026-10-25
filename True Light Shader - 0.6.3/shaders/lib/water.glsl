vec2 waterSlope(vec2 p, float t, float lod) {
    vec2 g = vec2(0.0);

    vec2 d1 = normalize(vec2(1.0, 0.3));
    vec2 d2 = normalize(vec2(0.6, -0.75));
    vec2 d3 = normalize(vec2(-0.5, 0.85));
    g += d1 * (0.060 * cos(dot(d1, p) * 0.571 + t * 1.66));
    g += d2 * (0.045 * cos(dot(d2, p) * 0.967 + t * 1.27));
    g += d3 * (0.035 * cos(dot(d3, p) * 1.653 + t * 0.975));

#if QUALITY >= 2
    const int OCT = 4;
#else
    const int OCT = 3;
#endif
    mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
    vec2 q = p;
    float amp = 0.11;
    float freq = 0.9;
    for (int i = 0; i < OCT; i++) {
        vec2 flow = vec2(0.30 + 0.12 * float(i), -0.20 + 0.07 * float(i)) * t;
        vec3 n = noised(q * freq + flow);
        g += n.yz * (amp * freq * 0.6);
        q = rot * q;
        freq *= 2.0;
        amp *= 0.55;
    }
    g *= mix(1.0, 0.45, lod);
    return g;
}

vec2 rainRippleSlope(vec2 p, float t) {
    vec2 g = vec2(0.0);
    for (int i = 0; i < 2; i++) {
        vec2 uvp = p * (2.6 + float(i) * 1.7) + vec2(float(i) * 7.3, float(i) * 3.1);
        vec2 id = floor(uvp);
        vec2 f = fract(uvp) - 0.5;
        float rnd = hash12(id);
        float phase = fract(t * 0.9 + rnd);
        vec2 jitter = (hash22(id + 4.7) - 0.5) * 0.5;
        vec2 d = f - jitter;
        float r = length(d);
        float ring = r - phase * 0.42;
        float env = exp(-ring * ring * 260.0) * (1.0 - phase) * step(rnd, 0.85);
        g += (d / max(r, 0.001)) * (cos(ring * 55.0) * 0.55 * env);
    }
    return g;
}

vec3 waterNormalWorld(vec2 p, float t, float viewDist) {
    float lod = clamp(viewDist / 96.0, 0.0, 1.0);
    vec2 g = waterSlope(p, t, lod);
#ifdef RAIN_RIPPLES
    if (rainStrength > 0.01) {
        g += rainRippleSlope(p, t) * (rainStrength * (1.0 - lod));
    }
#endif
    g *= WATER_WAVE_STRENGTH;
    return normalize(vec3(-g.x, 1.0, -g.y));
}
