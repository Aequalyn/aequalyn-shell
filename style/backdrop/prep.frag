// The desktop picture made ready for the blur, in one pass:
//  - drawn past the screen's edges (the edge pixels carried outwards), so the blur has
//    something to blend with there instead of fading to see-through;
//  - Maelstrom: twisted round a centre, most near it and not at all at the rim;
//  - Mosaic: broken into tiles;
//  - the shade laid over it, so it blurs, zooms and is masked with the picture.
// Compiled to prep.frag.qsb with:
//   /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o prep.frag.qsb prep.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 inset;      // the padding as a part of the screen (x, y)
    float twist;     // Maelstrom: radians at the centre
    float pull;      // Maelstrom: 0..1, how far it is drawn in
    float aspect;    // screen width / height
    float reach;     // Maelstrom: the swirl's reach, in screen heights
    vec2 center;     // Maelstrom: 0..1 on the screen
    vec2 cells;      // Mosaic: tiles across and down (0 = none)
    vec4 shade;      // rgb and how much of it
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = clamp(qt_TexCoord0 * (1.0 + 2.0 * inset) - inset, 0.0, 1.0);
    if (twist != 0.0 || pull != 0.0) {
        vec2 d = uv - center;
        d.x *= aspect;
        float k = clamp(1.0 - length(d) / reach, 0.0, 1.0);
        k = k * k * (3.0 - 2.0 * k);
        float a = twist * k;
        float s = sin(a), c = cos(a);
        d = vec2(c * d.x - s * d.y, s * d.x + c * d.y) * (1.0 - pull * k * 0.6);
        d.x /= aspect;
        uv = clamp(center + d, 0.0, 1.0);
    }
    if (cells.x > 0.0)
        uv = (floor(uv * cells) + 0.5) / cells;
    vec4 c = texture(source, uv);
    c.rgb = mix(c.rgb, shade.rgb * c.a, shade.a);
    fragColor = c * qt_Opacity;
}
