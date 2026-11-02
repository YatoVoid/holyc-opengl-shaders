uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform float uStrength;
uniform float uExposure;
out vec4 fragColor;

vec3 aces(vec3 x)
{
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main()
{
  vec2 uv = gl_FragCoord.xy / vec2(textureSize(uScene, 0));
  vec3 hdr = texture(uScene, uv).rgb + texture(uBloom, uv).rgb * uStrength;
  vec3 ldr = aces(hdr * uExposure);
  fragColor = vec4(pow(ldr, vec3(1.0 / 2.2)), 1.0);
}
