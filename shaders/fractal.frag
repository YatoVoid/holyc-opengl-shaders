#define MAX_STEPS 90
#define BAILOUT 4.0

vec4 trap;

float mandelbulb(vec3 p)
{
  float power = 6.0 + 2.0 * sin(iTime * 0.2);
  vec3 z = p;
  float dr = 1.0;
  float r = 0.0;
  trap = vec4(abs(p), dot(p, p));
  for (int i = 0; i < 8; i++) {
    r = length(z);
    if (r > BAILOUT) break;
    float theta = acos(z.z / r) * power;
    float phi = atan(z.y, z.x) * power;
    dr = pow(r, power - 1.0) * power * dr + 1.0;
    z = pow(r, power) * vec3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta)) + p;
    trap = min(trap, vec4(abs(z), dot(z, z)));
  }
  return 0.5 * log(r) * r / dr;
}

vec3 normalAt(vec3 p)
{
  vec2 e = vec2(0.0015, 0.0);
  return normalize(vec3(
    mandelbulb(p + e.xyy) - mandelbulb(p - e.xyy),
    mandelbulb(p + e.yxy) - mandelbulb(p - e.yxy),
    mandelbulb(p + e.yyx) - mandelbulb(p - e.yyx)));
}

vec3 palette(float t)
{
  return 0.5 + 0.5 * cos(6.2831 * (vec3(1.0, 1.0, 1.0) * t + vec3(0.0, 0.1, 0.2)));
}

void mainImage(out vec4 c, in vec2 fc)
{
  vec2 uv = (fc - 0.5 * iResolution.xy) / iResolution.y;

  float ang = iTime * 0.18;
  if (iMouse.z > 0.5) ang = (iMouse.x / iResolution.x) * 6.2831;
  vec3 ro = vec3(2.6 * sin(ang), 0.9 * sin(iTime * 0.13), 2.6 * cos(ang));
  vec3 ww = normalize(-ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = cross(uu, ww);
  vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.7 * ww);

  float d = 0.0;
  float steps = 0.0;
  bool hit = false;
  for (int i = 0; i < MAX_STEPS; i++) {
    float h = mandelbulb(ro + rd * d);
    if (h < 0.0006 * d) { hit = true; break; }
    d += h;
    steps += 1.0;
    if (d > 6.0) break;
  }

  vec3 bg = mix(vec3(0.02, 0.02, 0.05), vec3(0.08, 0.05, 0.12), uv.y + 0.5);
  vec3 col = bg;
  float glow = steps / float(MAX_STEPS);

  if (hit) {
    vec3 p = ro + rd * d;
    mandelbulb(p);
    vec3 n = normalAt(p);
    vec3 base = palette(0.15 + 0.6 * trap.w + 0.25 * trap.x);
    vec3 l = normalize(vec3(0.7, 0.9, 0.5));
    float diff = max(dot(n, l), 0.0);
    float occ = clamp(1.0 - glow * 1.4, 0.0, 1.0);
    float spec = pow(max(dot(reflect(-l, n), -rd), 0.0), 24.0);
    col = base * (0.15 + 0.95 * diff) * (0.35 + 0.65 * occ) + spec * 1.6;
  } else {
    col += vec3(0.9, 0.45, 0.7) * pow(glow, 2.2) * 2.6;
  }

  col *= 1.0 - 0.4 * dot(uv, uv);
  c = vec4(col, 1.0);
}
