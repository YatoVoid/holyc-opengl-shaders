uniform sampler2D uSource;
uniform vec2 uStep;
uniform vec2 uDest;
uniform float uPrefilter;
uniform float uThreshold;
uniform float uKnee;
out vec4 fragColor;

vec3 fetch(vec2 uv)
{
  vec3 c = texture(uSource, uv).rgb;
  if (uPrefilter > 0.5) {
    float peak = max(c.r, max(c.g, c.b));
    float soft = clamp(peak - uThreshold + uKnee, 0.0, 2.0 * uKnee);
    soft = soft * soft / (4.0 * uKnee + 1e-4);
    c *= max(soft, peak - uThreshold) / max(peak, 1e-4);
  }
  return c;
}

void main()
{
  vec2 uv = gl_FragCoord.xy / uDest;
  vec3 sum = fetch(uv) * 0.2270270270;
  sum += fetch(uv + uStep * 1.3846153846) * 0.3162162162;
  sum += fetch(uv - uStep * 1.3846153846) * 0.3162162162;
  sum += fetch(uv + uStep * 3.2307692308) * 0.0702702703;
  sum += fetch(uv - uStep * 3.2307692308) * 0.0702702703;
  fragColor = vec4(sum, 1.0);
}
