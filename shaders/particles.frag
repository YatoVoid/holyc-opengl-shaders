#define COUNT 140

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void mainImage(out vec4 c, in vec2 fc)
{
  vec2 uv = (fc - 0.5 * iResolution.xy) / iResolution.y;
  vec2 mouse = iMouse.z > 0.5 ? (iMouse.xy - 0.5 * iResolution.xy) / iResolution.y : vec2(0.0);

  vec3 col = mix(vec3(0.004, 0.006, 0.018), vec3(0.018, 0.008, 0.04), length(uv));

  for (int i = 0; i < COUNT; i++) {
    float id = float(i);
    float speed = 0.15 + 0.35 * hash(id + 1.0);
    float radius = 0.08 + 0.6 * hash(id + 2.0);
    float phase = 6.2831 * hash(id + 3.0);
    float tilt = (hash(id + 4.0) - 0.5) * 1.6;

    float a = iTime * speed + phase;
    vec2 p = vec2(cos(a), sin(a) * (0.35 + 0.5 * hash(id + 5.0))) * radius;
    p = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * p;
    p += mouse * 0.35 * (1.0 - radius);

    vec2 ba = -vec2(-sin(a), cos(a)) * 0.1;
    vec2 pa = uv - p;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h);

    float size = (0.0009 + 0.0012 * hash(id + 6.0)) * (1.0 - 0.5 * h);
    float glow = exp(-d * d / (size * size * 6.0)) * 2.2 * (1.0 - 0.9 * h) * (1.0 - 0.9 * h);
    vec3 tint = 0.55 + 0.45 * cos(6.2831 * (hash(id + 7.0) + vec3(0.0, 0.33, 0.67)));
    col += mix(tint, vec3(1.0), 0.6 * glow) * glow;
  }

  col = 1.0 - exp(-col * 1.3);
  col *= 1.0 - 0.3 * dot(uv, uv);
  col = pow(col, vec3(0.4545));
  c = vec4(col, 1.0);
}
