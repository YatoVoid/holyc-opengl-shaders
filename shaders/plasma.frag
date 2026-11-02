void mainImage(out vec4 c, in vec2 fc)
{
  vec2 uv = (fc - 0.5 * iResolution.xy) / iResolution.y;
  float v = sin(uv.x * 8.0 + iTime) + sin(uv.y * 9.0 - iTime * 1.3)
          + sin((uv.x + uv.y) * 7.0 + iTime * 0.7)
          + sin(length(uv) * 14.0 - iTime * 2.0);
  vec3 col = 0.5 + 0.5 * cos(vec3(0.0, 2.1, 4.2) + v);
  float ridge = pow(0.5 + 0.5 * sin(v * 1.5 - iTime), 8.0);
  c = vec4(col * (0.35 + 3.2 * ridge), 1.0);
}
