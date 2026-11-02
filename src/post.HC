// Bloom: the scene is drawn into a half-float texture, the bright parts are
// blurred at half resolution with a separable Gaussian (horizontal pass, then
// vertical pass, repeated), and a final pass adds the blur back, tone maps
// and writes to the screen. Needs g_vertex_src and gl.HC first.

#define BLOOM_ROUNDS    4
#define BLOOM_STRENGTH  0.65
#define BLOOM_THRESHOLD 1.0
#define BLOOM_KNEE      0.5

class Target
{
  U32 fbo;
  U32 tex;
  I32 w;
  I32 h;
};

class Post
{
  Target scene;
  Target a;
  Target b;
  U32 blur;
  U32 composite;
  Bool bloom;
};

Bool TargetInit(Target *t, I32 w, I32 h)
{
  t->w = w;
  t->h = h;
  glGenTextures(1, &t->tex);
  glBindTexture(GL_TEXTURE_2D, t->tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, w, h, 0, GL_RGBA, GL_FLOAT, NULL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  glGenFramebuffers(1, &t->fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, t->fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t->tex, 0);
  Bool ok = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  return ok;
}

U0 TargetFree(Target *t)
{
  if (!t->fbo)
    return;
  glDeleteFramebuffers(1, &t->fbo);
  glDeleteTextures(1, &t->tex);
  t->fbo = 0;
}

U32 LoadPostProgram(U8 *path)
{
  I64 size;
  U8 *body = FileRead(path, &size);
  if (!body) {
    "cannot read %s\n", path;
    return 0;
  }
  U8 *full = MStrPrint("#version 330 core\n%s", body);
  Free(body);
  U32 program = LinkProgram(g_vertex_src, full);
  Free(full);
  return program;
}

Bool PostInit(Post *p, Bool bloom)
{
  MemSet(p, 0, sizeof(Post));
  p->bloom = bloom;
  p->blur = LoadPostProgram("shaders/post/blur.frag");
  p->composite = LoadPostProgram("shaders/post/composite.frag");
  return p->blur && p->composite;
}

// Reallocates the render targets when the framebuffer size changes.
Bool PostResize(Post *p, I32 w, I32 h)
{
  if (p->scene.fbo && p->scene.w == w && p->scene.h == h)
    return TRUE;
  TargetFree(&p->scene);
  TargetFree(&p->a);
  TargetFree(&p->b);
  I32 hw = w / 2;
  I32 hh = h / 2;
  if (hw < 1) hw = 1;
  if (hh < 1) hh = 1;
  return TargetInit(&p->scene, w, h) && TargetInit(&p->a, hw, hh) && TargetInit(&p->b, hw, hh);
}

U0 BindTexture(U32 unit, U32 tex)
{
  glActiveTexture(GL_TEXTURE0 + unit);
  glBindTexture(GL_TEXTURE_2D, tex);
}

U0 BlurPass(Post *p, Target *dst, U32 src_tex, F64 dx, F64 dy, Bool prefilter, U32 vao)
{
  glBindFramebuffer(GL_FRAMEBUFFER, dst->fbo);
  glViewport(0, 0, dst->w, dst->h);
  glUseProgram(p->blur);
  BindTexture(0, src_tex);
  glUniform1i(glGetUniformLocation(p->blur, "uSource"), 0);
  glUniform2f(glGetUniformLocation(p->blur, "uStep"), dx, dy);
  glUniform2f(glGetUniformLocation(p->blur, "uDest"), dst->w, dst->h);
  F64 pre = 0.0;
  if (prefilter)
    pre = 1.0;
  glUniform1f(glGetUniformLocation(p->blur, "uPrefilter"), pre);
  glUniform1f(glGetUniformLocation(p->blur, "uThreshold"), BLOOM_THRESHOLD);
  glUniform1f(glGetUniformLocation(p->blur, "uKnee"), BLOOM_KNEE);
  glBindVertexArray(vao);
  glDrawArrays(GL_TRIANGLES, 0, 3);
}

// Call after the scene has been drawn into p->scene. Writes to the screen.
U0 PostResolve(Post *p, U32 vao, I32 w, I32 h)
{
  F64 strength = 0.0;
  if (p->bloom) {
    F64 tx = 1.0;
    tx /= p->a.w;
    F64 ty = 1.0;
    ty /= p->a.h;
    U32 src = p->scene.tex;
    for (I64 i = 0; i < BLOOM_ROUNDS; i++) {
      BlurPass(p, &p->a, src, tx, 0.0, i == 0, vao);
      BlurPass(p, &p->b, p->a.tex, 0.0, ty, FALSE, vao);
      src = p->b.tex;
    }
    strength = BLOOM_STRENGTH;
  }

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glViewport(0, 0, w, h);
  glUseProgram(p->composite);
  BindTexture(0, p->scene.tex);
  BindTexture(1, p->b.tex);
  glUniform1i(glGetUniformLocation(p->composite, "uScene"), 0);
  glUniform1i(glGetUniformLocation(p->composite, "uBloom"), 1);
  glUniform1f(glGetUniformLocation(p->composite, "uStrength"), strength);
  glUniform1f(glGetUniformLocation(p->composite, "uExposure"), 1.0);
  glBindVertexArray(vao);
  glDrawArrays(GL_TRIANGLES, 0, 3);
}
