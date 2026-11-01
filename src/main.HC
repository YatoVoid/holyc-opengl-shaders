// lumen: fragment shader scenes rendered from HolyC.
//
//   hcc src/main.HC -o build/lumen
//   ./build/lumen [scene]
//   ./build/lumen --render <scene> <out-dir> <frames> <fps> <width> <height>
//
// Keys: 1-4 switch scene, R reload, Esc quit. Saving a scene file reloads it.

#include "sdl2.HC"
#include "gl.HC"

extern "c" I32 atoi(U8 *s);

#define SCENE_COUNT 4

U8 *g_prelude =
  "#version 330 core\n"
  "uniform vec3 iResolution;\n"
  "uniform float iTime;\n"
  "uniform vec4 iMouse;\n"
  "out vec4 fragColor;\n"
  "#line 1\n";

U8 *g_vertex_src =
  "#version 330 core\n"
  "void main() {\n"
  "  vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);\n"
  "  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);\n"
  "}\n";

U8 *g_scenes[SCENE_COUNT] = {"raymarch", "particles", "fractal", "plasma"};

class Scene
{
  U8 *name;
  U8 *source;
  U8 *rejected;
  U32 program;
  I32 u_res, u_time, u_mouse;
  I64 checked_at;
};

U8 *LoadFragment(U8 *name)
{
  U8 *path = MStrPrint("shaders/%s.frag", name);
  I64 size;
  U8 *body = FileRead(path, &size);
  Free(path);
  if (!body)
    return NULL;
  U8 *full = MStrPrint("%s%s", g_prelude, body);
  Free(body);
  return full;
}

U32 BuildProgram(U8 *fragment)
{
  U8 *tail = MStrPrint("%s\nvoid main() { mainImage(fragColor, gl_FragCoord.xy); }\n", fragment);
  U32 program = LinkProgram(g_vertex_src, tail);
  Free(tail);
  return program;
}

// Returns TRUE when the scene now holds a working program. A scene that
// fails to compile keeps whatever was running before.
Bool SceneLoad(Scene *s, U8 *name)
{
  U8 *src = LoadFragment(name);
  if (!src) {
    "cannot read shaders/%s.frag\n", name;
    return FALSE;
  }
  U32 program = BuildProgram(src);
  if (!program) {
    Free(src);
    return FALSE;
  }
  if (s->program)
    glDeleteProgram(s->program);
  Free(s->source);
  s->name = name;
  s->source = src;
  s->program = program;
  s->u_res = glGetUniformLocation(program, "iResolution");
  s->u_time = glGetUniformLocation(program, "iTime");
  s->u_mouse = glGetUniformLocation(program, "iMouse");
  return TRUE;
}

U0 SceneWatch(Scene *s, I64 now)
{
  if (now - s->checked_at < 250)
    return;
  s->checked_at = now;
  U8 *src = LoadFragment(s->name);
  Bool changed = src && StrCmp(src, s->source) && (!s->rejected || StrCmp(src, s->rejected));
  Free(src);
  if (changed) {
    "reloading %s\n", s->name;
    if (!SceneLoad(s, s->name)) {
      Free(s->rejected);
      s->rejected = LoadFragment(s->name);
    }
  }
}

U0 SceneDraw(Scene *s, U32 vao, F64 t, I32 w, I32 h, F64 mx, F64 my, F64 click)
{
  glViewport(0, 0, w, h);
  glUseProgram(s->program);
  glUniform3f(s->u_res, w, h, 1.0);
  glUniform1f(s->u_time, t);
  glUniform4f(s->u_mouse, mx, my, click, 0.0);
  glBindVertexArray(vao);
  glDrawArrays(GL_TRIANGLES, 0, 3);
}

U0 *g_context;

U0 *OpenWindow(I32 w, I32 h, Bool visible)
{
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    "SDL_Init failed: %s\n", SDL_GetError();
    return NULL;
  }
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

  U32 show = SDL_WINDOW_HIDDEN;
  if (visible)
    show = SDL_WINDOW_SHOWN;
  U0 *window = SDL_CreateWindow("lumen", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                w, h, SDL_WINDOW_OPENGL | show);
  if (!window) {
    "SDL_CreateWindow failed: %s\n", SDL_GetError();
    return NULL;
  }
  g_context = SDL_GL_CreateContext(window);
  if (!g_context) {
    "SDL_GL_CreateContext failed: %s\n", SDL_GetError();
    SDL_DestroyWindow(window);
    return NULL;
  }
  return window;
}

I32 RenderToDisk(U8 *name, U8 *dir, I64 frames, I64 fps, I32 w, I32 h)
{
  U0 *window = OpenWindow(w, h, FALSE);
  if (!window)
    return 1;

  U32 vao;
  glGenVertexArrays(1, &vao);
  Scene scene;
  MemSet(&scene, 0, sizeof(Scene));
  if (!SceneLoad(&scene, name))
    return 1;

  for (I64 i = 0; i < frames; i++) {
    F64 t = i;
    t /= fps;
    SceneDraw(&scene, vao, t, w, h, 0.0, 0.0, 0.0);
    U8 *path = MStrPrint("%s/f%05d.ppm", dir, i);
    Bool ok = GlSavePpm(path, w, h);
    Free(path);
    if (!ok) {
      "could not write frame %d to %s\n", i, dir;
      return 1;
    }
  }
  return 0;
}

I32 Main(I32 argc, U8 **argv)
{
  if (argc >= 8 && !StrCmp(argv[1], "--render"))
    return RenderToDisk(argv[2], argv[3], atoi(argv[4]), atoi(argv[5]),
                        atoi(argv[6]), atoi(argv[7]));

  U8 *first = g_scenes[0];
  if (argc > 1)
    first = argv[1];

  U0 *window = OpenWindow(1280, 720, TRUE);
  if (!window)
    return 1;
  SDL_GL_SetSwapInterval(1);
  "OpenGL %s on %s\n", glGetString(GL_VERSION), glGetString(GL_RENDERER);

  U32 vao;
  glGenVertexArrays(1, &vao);
  Scene scene;
  MemSet(&scene, 0, sizeof(Scene));
  if (!SceneLoad(&scene, first))
    return 1;

  while (SdlPumpEvents() && !SdlKeyDown(SC_ESCAPE)) {
    for (I64 k = 0; k < SCENE_COUNT; k++)
      if (SdlKeyDown(SC_1 + k) && StrCmp(scene.name, g_scenes[k]))
        SceneLoad(&scene, g_scenes[k]);
    if (SdlKeyDown(SC_R))
      SceneLoad(&scene, scene.name);

    I64 now = SDL_GetTicks();
    SceneWatch(&scene, now);

    I32 w, h, mx, my;
    SDL_GL_GetDrawableSize(window, &w, &h);
    U32 buttons = SDL_GetMouseState(&mx, &my);
    F64 t = now;
    t /= 1000.0;
    SceneDraw(&scene, vao, t, w, h, mx, h - my, buttons & SDL_BUTTON_LMASK);
    SDL_GL_SwapWindow(window);
  }

  SDL_GL_DeleteContext(g_context);
  SDL_DestroyWindow(window);
  SDL_Quit();
  return 0;
}
