precision highp float;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);

    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.05 + 17.3;
        a *= 0.5;
    }

    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 designResolution = vec2(800.0, 450.0);
    float scale = iResolution.y / designResolution.y;
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / scale + 0.5 * designResolution;
    uv /= designResolution;

    float t = iTime * 0.16;
    uv.x += sin(iTime * 0.5 + uv.y * 10.0) * 0.05;
    uv.y += cos(iTime * 0.5 + uv.x * 10.0) * 0.05;

    vec2 p = (uv - 0.5) * vec2(designResolution.x / designResolution.y, 1.0);
    p *= 3.15;

    vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3 - t)));
    vec2 r = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2)), fbm(p + 4.0 * q + vec2(8.3, 2.8)));
    float n = fbm(p + 4.8 * r);

    float veins = 1.0 - smoothstep(0.055, 0.18, abs(sin((n + r.x * 0.55) * 35.0)));
    float ridges = 1.0 - smoothstep(0.08, 0.23, abs(sin((n + q.y * 0.35) * 18.0)));
    float fine = 1.0 - smoothstep(0.012, 0.06, abs(sin((n + q.x) * 82.0)));

    vec3 col = vec3(0.005, 0.006, 0.010);
    col += vec3(0.28, 0.30, 0.32) * ridges;
    col += vec3(0.17, 0.18, 0.19) * veins;
    col += vec3(0.02, 0.03, 0.55) * fine * (0.35 + 0.65 * noise(p * 7.0));
    col += vec3(0.36, 0.34, 0.02) * fine * veins * 0.32;

    col *= 0.72 + 0.28 * smoothstep(0.15, 0.95, n);
    col = max(col - 0.015, 0.0);

    fragColor = vec4(col, 1.0);
}
