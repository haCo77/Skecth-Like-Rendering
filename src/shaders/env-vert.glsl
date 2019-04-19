#version 300 es
precision highp float;

// The vertex shader used to render the background of the scene
uniform vec2 u_Dimensions;
uniform mat4 u_ViewProj;

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec2 vs_UV;
out vec4 fs_Nor;
out vec4 fs_Pos;
out vec2 fs_UV;

void main() {
  fs_Nor = vs_Nor;
  fs_UV = vs_UV;
  fs_Pos = vs_Pos;
  gl_Position = u_ViewProj * vs_Pos;
}