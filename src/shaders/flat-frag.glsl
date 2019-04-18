#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec4 u_Color;

in vec2 fs_Pos;
out vec4 out_Col;

#define MAX_STEPS 100
#define EPSILON 0.0001
#define SPEED 0.2
#define PI 3.1415926

const vec3 LIGHTPos1 = vec3(1.0, 5.0, 1.6);
const vec3 LIGHTPos2 = vec3(-1.0, 5.0, 1.6);
const vec3 LIGHTPos3 = vec3(-0.1, 5.0, -1.0);
const vec4 paperCol = vec4(225.0 / 255.0, 227.0 / 255.0, 221.0 / 255.0, 1.0);
const float lineWidth = 0.05;

vec2 random2(vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(3.117, 1.271)), dot(p + seed, vec2(2.695, 1.833)))) * 853.545);
}

vec3 transform(vec3 pos, vec3 trans, vec3 scale, float degree) {
  float c = cos(degree * 3.1415926 / 180.0);
  float s = sin(degree * 3.1415926 / 180.0);
  mat2  m = mat2(c, -s, s, c);
  pos.xz = m * pos.xz;
  return (pos - trans) / scale;
}

vec2 repeat(vec2 pos, float t){
	t = 2. * PI / t;
    float angle = mod(atan(pos.y, pos.x) , t) - 0.5 * t;
    float r = length(pos);
    return r * vec2(cos(angle), sin(angle));
}

float smoothabs(float p, float k){
	return sqrt(p * p + k * k) - k;
}

mat2 rot(float a){
    float c = cos(a);
    float s = sin(a);
	return mat2(c, -s, s, c);
}

float Sphere(vec3 p)
{
  return length(p) - 100.0;
}

float pRoundBox(vec3 p) {
  vec3 b = vec3(1.0, 1.0, 1.0);
  float r = 0.3;
  return length(max(abs(p) - b, 0.0)) - r;
}

float Box(vec3 p)
{
  vec3 b = vec3(3.0, 3.0, 3.0);
  vec3 d = abs(p) - b;
  return length(max(d,0.0)) + min(max(d.x,max(d.y,d.z)),0.0);
}

float flower(vec3 pos) {
  float radius = 1.5;
  vec3 p = pos;
  p.xz = rot(0.628) * p.xz;
  p.xz = repeat(p.xz, 5.0);
  p.xy = rot(0.99) * p.xy;
  p.y = abs(p.y);
  p.z = smoothabs(p.z, 0.01);
  float d = length(p - vec3(0.3889 * radius, -0.66116 * radius, -0.66116 * radius)) - radius;
    
  p = pos;
  p.xz = repeat(p.xz, 7.0);
  p.xy = rot(0.75) * p.xy;
  p.y = abs(p.y);
  p.z = smoothabs(p.z, 0.01);
  radius = 1.8;
  d = min(d, length(p - vec3(0.3889 * radius, -0.66116 * radius, -0.66116 * radius)) - radius);

  p = pos;
  p.xz = repeat(p.xz, 5.0);
  p.xy = rot(1.3) * p.xy;
  p.y = abs(p.y);
  p.z = smoothabs(p.z, 0.01);
  radius = 1.4;
  d = min(d, length(p - vec3(0.3889 * radius, -0.66116 * radius, -0.66116 * radius)) - radius);
 
  return d;
}

vec3 calcNormal(vec3 x, float eps)
{
    vec2 e = vec2(eps, 0.0);
    return normalize(vec3(flower(x + e.xyy) - flower(x - e.xyy),
                            flower(x + e.yxy) - flower(x - e.yxy),
                            flower(x + e.yyx) - flower(x - e.yyx)));
}

vec2 minDist(vec3 pos) {
  float d = flower(pos);
  if(d < pos.y || pos.y < -0.001)
    return vec2(d, 2.0);
  else {
    return vec2(pos.y, 3.0);
  }
}

vec2 checkBoundingBox(vec2 xrange, vec2 yrange, vec2 zrange, vec3 ori, vec3 dir) {
  float t1, t2;
  float f1, f2;
  vec3 p1, p2;
  bool first = false;
  if(dir.z != 0.0) {
    t1 = (zrange.x - ori.z) / dir.z;
    t2 = (zrange.y - ori.z) / dir.z;
    if(t1 >= 0.0) {
      p1 = ori + t1 * dir;
      if(p1.x <= xrange.y && p1.x >= xrange.x && p1.y <= yrange.y && p1.y >= yrange.x) {
        first = true;
        f1 = t1;
      }
    }
    if(t2 >= 0.0) {
      p2 = ori + t2 * dir;
      if(p2.x <= xrange.y && p2.x >= xrange.x && p2.y <= yrange.y && p2.y >= yrange.x) {
        if(first) {
          return vec2(min(f1, t2), max(f1, t2));
        }
        else {
          first = true;
          f1 = t2;
        }
      }
    }
  }
  if(dir.y != 0.0) {
    t1 = (yrange.x - ori.y) / dir.y;
    t2 = (yrange.y - ori.y) / dir.y;
    if(t1 >= 0.0) {
      p1 = ori + t1 * dir;
      if(p1.x <= xrange.y && p1.x >= xrange.x && p1.z <= zrange.y && p1.z >= zrange.x) {
        if(first) {
          return vec2(min(f1, t1), max(f1, t1));
        } else {
          first = true;
          f1 = t1;
        }
      }
    }
    if(t2 >= 0.0) {
      p2 = ori + t2 * dir;
      if(p2.x <= xrange.y && p2.x >= xrange.x && p2.z <= zrange.y && p2.z >= zrange.x) {
        if(first) {
          return vec2(min(f1, t2), max(f1, t2));
        }
        else {
          first = true;
          f1 = t2;
        }
      }
    }
  }
  if(dir.x != 0.0) {
    t1 = (xrange.x - ori.x) / dir.x;
    t2 = (xrange.y - ori.x) / dir.x;
    if(t1 >= 0.0) {
      p1 = ori + t1 * dir;
      if(p1.y <= yrange.y && p1.y >= yrange.x && p1.z <= zrange.y && p1.z >= zrange.x) {
        if(first) {
          return vec2(min(f1, t1), max(f1, t1));
        } else {
          first = true;
          f1 = t1;
        }
      }
    }
    if(t2 >= 0.0) {
      p2 = ori + t2 * dir;
      if(p2.y <= yrange.y && p2.y >= yrange.x && p2.z <= zrange.y && p2.z >= zrange.x) {
        if(first) {
          return vec2(min(f1, t2), max(f1, t2));
        }
        else {
          return vec2(t2, t2);
        }
      }
    }
  }
  if(first)
    return vec2(f1, f1);
  return vec2(0.0, 0.0);
}

float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 32; i++)
    {
        float h = flower(ro + rd * t);
        res = min(res, k * h / t);
        t += h;
        if(t > maxt) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec4 rayMarch(vec3 ori, vec3 dir, bool ifBB) {
  float t;
  vec2 trange;
  if(ifBB) {
    trange = checkBoundingBox(vec2(-2.0, 2.0), vec2(-0.5, 2.0), vec2(-2.0, 2.0), ori, dir);
    if(trange.x == 0.0 && trange.y == 0.0) {
      return vec4(0.0);
    }
    t = trange.x;
  } else {
    t = 0.0;
  }
  float last_d = 10000.0;
  vec3 pos;
  for(int i = 0; i < MAX_STEPS; i++) {
    pos = ori + t * dir;
    vec2 d = minDist(pos);
    if(last_d < lineWidth && d.x > last_d + 0.00001 && d.y != 3.0) {
      return vec4(1.0);
    }
    last_d = d.x;
    if(abs(d.x) < EPSILON) {
      return vec4(d.y, pos);
    }
    if(d.x < 0.0) {
        return vec4(0.0);
    }
    t += d.x;
    if(ifBB && t > trange.y) {
      return vec4(0.0);
    }
  }
  return vec4(0.0);
}

vec3 getDir(vec3 H, float len, vec2 coord) {
  return normalize(u_Ref - u_Eye + coord.x * H + coord.y * u_Up * len);
}

vec4 render(vec3 ori, vec3 dir, vec2 p) {
  vec4 ip = rayMarch(ori, dir, true);
  vec4 col;
  vec3 nor = vec3(0.0);
  if(ip.x == 0.0) {
    col = paperCol;
  } else if(ip.x == 1.0) {
    col = u_Color;
  } else if(ip.x == 2.0) {
    nor = calcNormal(ip.yzw, 0.001);
    float ndv0 = dot(nor, -dir);
    vec3 w = normalize(-dir - ndv0 * nor);
    vec3 ori1 = ip.yzw + w * 0.05;
    vec3 dir1 = normalize(ori1 - ori);
    vec4 ip1 = rayMarch(ori1, dir1, false);
    vec3 ori2 = ip.yzw - w * 0.05;
    vec3 dir2 = normalize(ori2 - ori);
    vec4 ip2 = rayMarch(ori2 - 0.1 * dir2, dir2, false);
    if(ip1.x == 2.0 && ip2.x == 2.0) {
      float ndv1 = dot(calcNormal(ip1.yzw, 0.001), -dir1);
      float ndv2 = dot(calcNormal(ip2.yzw, 0.001), -dir2);
      if(ndv1 > ndv0 && ndv2 > ndv0) {
        // col = paperCol;
         col = u_Color;
      } else {
        col = paperCol;
      }
    } else {
      col = paperCol;
    }
  } else {
    nor = vec3(0.0, 1.0, 0.0);
    col = paperCol + vec4(0.05, 0.05, 0.05, 0.0);
  }
  if(nor.x != 0.0 || nor.y != 0.0 || nor.z != 0.0) {
    float diffuse = max(dot(nor, normalize(LIGHTPos1 - ip.yzw)), 0.0);
    diffuse += max(dot(nor, normalize(LIGHTPos2 - ip.yzw)), 0.0);
    diffuse += max(dot(nor, normalize(LIGHTPos3 - ip.yzw)), 0.0);
    diffuse = diffuse * 0.5 + 0.2;
    float res = softshadow(ip.yzw, normalize(LIGHTPos1 - ip.yzw), 0.01, 2.0, 1.0);
    res += softshadow(ip.yzw, normalize(LIGHTPos2 - ip.yzw), 0.01, 2.0, 1.0);
    res += softshadow(ip.yzw, normalize(LIGHTPos3 - ip.yzw), 0.01, 2.0, 1.0);
    diffuse *= clamp(res, 0.0, 1.0); 
    float h = clamp(max(sin(p.x * 720.0 + p.y * 570.0) * 0.5 + 0.5,
                        sin(-p.x * 570.0 + p.y * 720.0) * 0.5 + 0.3) 
                     - diffuse, 0.0 ,1.0);
    col = mix(col, u_Color, h);
  }
  return col;
}

void main() {
  float len = length(u_Ref - u_Eye);
  vec3 H = normalize(cross(u_Ref - u_Eye, u_Up)) * len * u_Dimensions.x / u_Dimensions.y;
  // vec2 delta = vec2(2.0 / u_Dimensions.x, 2.0 / u_Dimensions.y);
  vec4 color = render(u_Eye, getDir(H, len, fs_Pos), fs_Pos);

  out_Col = color;
}
