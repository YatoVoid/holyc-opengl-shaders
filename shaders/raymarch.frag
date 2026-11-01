#define MAX_STEPS 120
#define MAX_DIST 40.0
#define EPS 0.0005

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdBox(vec3 p, vec3 b)
{
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t)
{
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

float smin(float a, float b, float k)
{
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

mat2 rot(float a)
{
  float c = cos(a), s = sin(a);
  return mat2(c, -s, s, c);
}

// x: distance, y: material id (0 floor, 1 blob, 2 torus, 3 box)
vec2 map(vec3 p)
{
  float t = iTime;
  vec2 res = vec2(p.y + 1.0, 0.0);

  vec3 b = p - vec3(sin(t * 0.9) * 0.9, 0.0 + sin(t * 1.3) * 0.25, 0.0);
  float blob = sdSphere(b, 0.7);
  blob = smin(blob, sdSphere(p - vec3(-sin(t * 0.7) * 1.1, 0.15, cos(t * 0.8) * 0.5), 0.5), 0.6);
  if (blob < res.x) res = vec2(blob, 1.0);

  vec3 q = p - vec3(0.0, 0.25, 0.0);
  q.xy *= rot(t * 0.6);
  q.yz *= rot(t * 0.4);
  float tor = sdTorus(q, vec2(1.5, 0.12));
  if (tor < res.x) res = vec2(tor, 2.0);

  vec3 r = p - vec3(2.1 * cos(t * 0.5), -0.55, 2.1 * sin(t * 0.5));
  r.xz *= rot(t);
  float box = sdBox(r, vec3(0.32)) - 0.04;
  if (box < res.x) res = vec2(box, 3.0);

  return res;
}

vec3 normalAt(vec3 p)
{
  vec2 e = vec2(0.001, 0.0);
  return normalize(vec3(
    map(p + e.xyy).x - map(p - e.xyy).x,
    map(p + e.yxy).x - map(p - e.yxy).x,
    map(p + e.yyx).x - map(p - e.yyx).x));
}

vec2 march(vec3 ro, vec3 rd)
{
  float d = 0.0;
  for (int i = 0; i < MAX_STEPS; i++) {
    vec2 h = map(ro + rd * d);
    if (h.x < EPS) return vec2(d, h.y);
    d += h.x;
    if (d > MAX_DIST) break;
  }
  return vec2(MAX_DIST, -1.0);
}

float softShadow(vec3 ro, vec3 rd, float k)
{
  float res = 1.0;
  float d = 0.02;
  for (int i = 0; i < 48; i++) {
    float h = map(ro + rd * d).x;
    res = min(res, k * h / d);
    d += clamp(h, 0.02, 0.4);
    if (res < 0.001 || d > 12.0) break;
  }
  return clamp(res, 0.0, 1.0);
}

float ambientOcclusion(vec3 p, vec3 n)
{
  float occ = 0.0;
  float w = 1.0;
  for (int i = 1; i <= 5; i++) {
    float h = 0.04 * float(i);
    occ += (h - map(p + n * h).x) * w;
    w *= 0.7;
  }
  return clamp(1.0 - 2.2 * occ, 0.0, 1.0);
}

vec3 albedo(vec3 p, float id)
{
  if (id < 0.5) {
    float check = mod(floor(p.x) + floor(p.z), 2.0);
    return mix(vec3(0.07, 0.08, 0.1), vec3(0.2, 0.22, 0.26), check);
  }
  if (id < 1.5) return vec3(0.95, 0.35, 0.25);
  if (id < 2.5) return vec3(0.9, 0.78, 0.4);
  return vec3(0.3, 0.6, 0.95);
}

vec3 sky(vec3 rd)
{
  vec3 top = vec3(0.04, 0.06, 0.12);
  vec3 low = vec3(0.35, 0.28, 0.4);
  return mix(low, top, clamp(rd.y * 1.4 + 0.2, 0.0, 1.0));
}

vec3 shade(vec3 ro, vec3 rd, vec2 hit, vec3 lightDir)
{
  if (hit.y < 0.0) return sky(rd);
  vec3 p = ro + rd * hit.x;
  vec3 n = normalAt(p);
  vec3 base = albedo(p, hit.y);

  float diff = max(dot(n, lightDir), 0.0);
  float sh = softShadow(p + n * 0.01, lightDir, 12.0);
  float occ = ambientOcclusion(p, n);
  float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
  vec3 h = normalize(lightDir - rd);
  float spec = pow(max(dot(n, h), 0.0), 48.0);

  vec3 col = base * (vec3(1.0, 0.9, 0.75) * diff * sh * 1.5 + sky(n) * 0.6 * occ);
  col += spec * sh * 0.8;
  col += rim * sky(reflect(rd, n)) * 0.5 * occ;
  return col;
}

void mainImage(out vec4 c, in vec2 fc)
{
  vec2 uv = (fc - 0.5 * iResolution.xy) / iResolution.y;

  float ang = iTime * 0.25;
  if (iMouse.z > 0.5) ang = (iMouse.x / iResolution.x) * 6.2831;
  vec3 ro = vec3(5.2 * sin(ang), 2.0 + 0.6 * sin(iTime * 0.3), 5.2 * cos(ang));
  vec3 ta = vec3(0.0, 0.1, 0.0);
  vec3 ww = normalize(ta - ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = cross(uu, ww);
  vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.8 * ww);

  vec3 lightDir = normalize(vec3(0.6, 0.8, 0.4));
  vec2 hit = march(ro, rd);
  vec3 col = shade(ro, rd, hit, lightDir);

  // one mirror bounce, strongest on the floor
  if (hit.y >= 0.0) {
    vec3 p = ro + rd * hit.x;
    vec3 n = normalAt(p);
    float fres = pow(1.0 - max(dot(n, -rd), 0.0), 4.0);
    float k = hit.y < 0.5 ? 0.35 : 0.15 + 0.4 * fres;
    vec3 rr = reflect(rd, n);
    vec2 h2 = march(p + n * 0.01, rr);
    col = mix(col, shade(p + n * 0.01, rr, h2, lightDir), k);
  }

  float fog = 1.0 - exp(-hit.x * 0.035);
  col = mix(col, sky(rd), fog * step(0.0, hit.y));

  col *= 1.0 - 0.35 * dot(uv, uv);
  col = pow(col, vec3(0.4545));
  c = vec4(col, 1.0);
}
