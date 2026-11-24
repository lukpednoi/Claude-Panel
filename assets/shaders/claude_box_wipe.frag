#version 440

// Claude welcome card: layered liquid-light waves sweep from the bottom-left corner (where the launch
// streak arrives from CornerRevolver) to the top-right corner. Nothing is drawn ahead of the leading
// wave (no murky veil), while warm terracotta-orange wave ribbons crest cleanly into the crisp card.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float reveal;
    float amp;
    float radius;
    vec4 crest;
};

layout(binding = 1) uniform sampler2D source;

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;

float waveLayerDist(float idx, float q, float u, float phase, float ampQ, float stagger, out bool started, out bool finished) {
    float prog = clamp((reveal - idx * stagger) / (1.0 - 3.0 * stagger), 0.0, 1.0);
    started = prog > 0.0005;
    finished = prog >= 0.9995;
    if (!started || finished) return 0.0;

    float eased = mix(prog, prog * prog * (3.0 - 2.0 * prog), 0.65);
    float env = pow(sin(eased * PI), 0.72);

    float f1 = 1.35 + idx * 0.25;
    float f2 = 2.75 + idx * 0.35;
    float ph1 = phase * (1.0 + idx * 0.14) + idx * 1.4;
    float ph2 = -phase * 1.25 + idx * 2.3;
    float ripple = sin(u * TAU * f1 + ph1) * 0.64 + sin(u * TAU * f2 + ph2) * 0.36;

    float front = eased + ripple * ampQ * env * (1.0 - idx * 0.08);
    return q - front; // <= 0 means behind the wave (already covered)
}

vec4 blendWaveRibbon(vec4 accum, vec4 col, float d, float spanPx) {
    float edge = clamp(0.5 - d * spanPx, 0.0, 1.0);
    // Subtle luminous highlight right along the crest of each liquid ribbon
    float rim = exp(-abs(d) * spanPx / 5.5) * 0.22 * col.a;
    vec4 lit = vec4(min(col.rgb + crest.rgb * rim, vec3(col.a)), col.a);
    return mix(accum, lit, edge);
}

void main() {
    vec4 content = texture(source, qt_TexCoord0);

    if (reveal >= 0.999) {
        fragColor = content * qt_Opacity;
        return;
    }
    if (reveal <= 0.0005) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;

    // Clamped to the card's rounded rectangle
    vec2 halfSize = itemSize * 0.5;
    vec2 rel = abs(p - halfSize) - (halfSize - vec2(radius));
    float sd = length(max(rel, vec2(0.0))) + min(max(rel.x, rel.y), 0.0) - radius;
    float inside = 1.0 - smoothstep(-0.75, 0.75, sd);
    if (inside <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    float span = max(1.0, itemSize.x + itemSize.y);
    // 0.0 at bottom-left corner -> 1.0 at top-right corner
    float q = (p.x + (itemSize.y - p.y)) / span;
    // Orthogonal axis across the diagonal wavefront
    float u = (p.x + p.y) / span;
    float phase = reveal * 7.5;
    float ampQ = amp / span;
    float stagger = 0.075;

    vec4 accum = vec4(0.0);

    // Layer 0: deep dark-amber leading body
    bool s0, f0;
    float d0 = waveLayerDist(0.0, q, u, phase, ampQ, stagger, s0, f0);
    if (f0) {
        accum = vec4(0.08, 0.045, 0.035, 0.92);
    } else if (s0) {
        accum = blendWaveRibbon(accum, vec4(0.08, 0.045, 0.035, 0.92), d0, span);
    }

    // Layer 1: rich burnt-terracotta mid ribbon
    bool s1, f1;
    float d1 = waveLayerDist(1.0, q, u, phase, ampQ, stagger, s1, f1);
    vec4 col1 = vec4(crest.rgb * 0.52, 0.96);
    if (f1) {
        accum = col1;
    } else if (s1) {
        accum = blendWaveRibbon(accum, col1, d1, span);
    }

    // Layer 2: vibrant Claude orange crest ribbon
    bool s2, f2;
    float d2 = waveLayerDist(2.0, q, u, phase, ampQ, stagger, s2, f2);
    vec4 col2 = vec4(crest.rgb * 0.92, 0.98);
    if (f2) {
        accum = col2;
    } else if (s2) {
        accum = blendWaveRibbon(accum, col2, d2, span);
    }

    // Layer 3: final reveal wave exposing the real card content cleanly
    bool s3, f3;
    float d3 = waveLayerDist(3.0, q, u, phase, ampQ, stagger, s3, f3);
    if (f3) {
        accum = content;
    } else if (s3) {
        float showEdge = clamp(0.5 - d3 * span, 0.0, 1.0);
        // Thin luminous orange edge right where the card materializes behind the orange ribbon
        float sparkEdge = exp(-abs(d3) * span / 4.0) * 0.35 * (1.0 - reveal * 0.6);
        vec4 revealed = content;
        revealed.rgb = min(revealed.rgb + crest.rgb * sparkEdge * content.a, vec3(content.a));
        accum = mix(accum, revealed, showEdge);
    }

    fragColor = accum * qt_Opacity * inside;
}
