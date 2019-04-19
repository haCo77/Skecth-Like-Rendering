#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform sampler2D u_Texture1;
uniform sampler2D u_Texture2;

in vec4 fs_Pos;
in vec4 fs_Nor;
in vec2 fs_UV;
out vec4 out_Col;

void main() {
  vec4 tmp = texture(u_Texture1, vec2(1.0 - fs_UV.x, fs_UV.y));
  out_Col = tmp;
}
