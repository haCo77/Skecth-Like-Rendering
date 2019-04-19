#version 300 es
precision highp float;

// The vertex shader used to render the background of the scene
uniform vec2 u_Dimensions;
uniform mat4 u_ViewProj;
uniform float u_Time;

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
  vec4 pos = vs_Pos;
  pos.z += 0.03 * sin(0.5 * pos.y + u_Time * 0.05) * (0.65 - pos.y);
  gl_Position = u_ViewProj * pos;
}