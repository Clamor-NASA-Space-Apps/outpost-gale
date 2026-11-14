# Excerpt: OpenGL program binaries on macOS (saved 14 Nov 2026; Packt page blocks curl)
- https://packtpub.com/en-mt/product/opengl-4-shading-language-cookbook-9781789342253/chapter/getting-started-with-glsl-1/section/saving-and-loading-a-shader-binary-ch01lvl1sec08
  OpenGL 4 Shading Language Cookbook: the Intel drivers on macOS do not support any binary formats (GL_NUM_PROGRAM_BINARY_FORMATS = 0). Says nothing about Apple Silicon. (reported)
- https://community.khronos.org/t/glprogrambinary-missing-condition/112307: zero formats is a legal driver answer; compile from source then. (reported)
