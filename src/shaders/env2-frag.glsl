#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec4 u_Color;
uniform sampler2D u_Texture1;
uniform sampler2D u_Texture2;

in vec2 fs_Pos;
out vec4 out_Col;

#define MAX_STEPS 100
#define EPSILON 0.0001
#define SPEED 0.2
#define PI 3.1415926

const vec3 LIGHTPos1 = vec3(-0.5, -1.5, -3.0);
const vec3 LIGHTPos2 = vec3(-0.8, -1.2, -3.0);
const vec3 LIGHTPos3 = vec3(-0.6, -0.8, -3.0);
const vec4 paperCol = vec4(225.0 / 255.0, 227.0 / 255.0, 221.0 / 255.0, 1.0);

vec2 random2(vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(3.117, 1.271)), dot(p + seed, vec2(2.695, 1.833)))) * 853.545);
}

float sdCylinderZY(vec3 p, vec2 h) {
  vec2 d = abs(vec2(length(p.zy), p.x)) - h;
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdHexPrism(vec3 p, vec2 h) {
    vec3 q = abs(p);
    float d1 = q.x - h.y;
    float d2 = max((q.z * 0.866025 + q.y * 0.5), q.y) - h.x;
    return length(max(vec2(d1, d2), 0.0)) + min(max(d1, d2), 0.);
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdCone(vec3 p, vec2 c) {
    float q = length(p.yz);
    return dot(c, vec2(q, p.x));
}

vec3 pencilTrans(vec3 pos, float a) {
  pos *= 3.0;
  pos.yz = pos.zy;
  pos.xz = mat2(0.581683089463883,-0.813415504789374,
                0.813415504789374, 0.581683089463883) * pos.xz;
  pos += a * vec3(-0.5, 0.2, -2.7);
  return pos;
}

vec2 minDist(vec3 pos) {
  pos = pencilTrans(pos, 1.0);
  vec2 res = vec2(100000.0, 0.0);
  float dPencil0 = sdHexPrism(pos, vec2(0.18, 2.5));
  dPencil0 = max(sdCone(pos + (vec3(-2.55, 0.0, 0.0)), vec2(.95, 0.3122)), dPencil0);
  if (dPencil0 < res.x) res = vec2(dPencil0, 2.0);

  float dPencil1 = sdCapsule(pos, - vec3(2.7, 0.0, 0.0), -vec3(3.05, 0.0, 0.0), 0.185);
  if (dPencil1 < res.x) res = vec2(dPencil1, 3.0);
  float ax = abs(-2.75 - pos.x);
  float r = 0.01 * abs(2.0 * fract(30.0 * pos.x) - 1.0) 
                * smoothstep(0.10, 0.11, ax) * smoothstep(0.21, 0.20, ax);

  float dPencil2 = sdCylinderZY(pos + vec3(2.75, 0.0, 0.0), vec2(0.2 - r, 0.25));
  if (dPencil2 < res.x) res = vec2(dPencil2, 4.0);

  res.x /= 3.0;
  return res;
}

vec3 calcNormal(vec3 x, float eps)
{
    vec2 e = vec2(eps, 0.0);
    return normalize(vec3(minDist(x + e.xyy).r - minDist(x - e.xyy).r,
                            minDist(x + e.yxy).r - minDist(x - e.yxy).r,
                            minDist(x + e.yyx).r - minDist(x - e.yyx).r));
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
          return vec2(0.0, t2);
        }
      }
    }
  }
  if(first)
    return vec2(0.0, f1);
  return vec2(0.0, 0.0);
}

float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 32; i++)
    {
        float h = minDist(ro + rd * t).x;
        res = min(res, k * h / t);
        t += h;
        if(t > maxt) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec4 rayMarch(vec3 ori, vec3 dir, bool ifBB) {
  float t;
  vec2 trange;
  vec4 res = vec4(0.0);
  if(ifBB) {
    vec3 ori_ = pencilTrans(ori, 1.0);
    vec3 dir_ = pencilTrans(dir, 0.0);
    trange = checkBoundingBox(vec2(-3.6, 3.6), vec2(-0.24, 0.2), vec2(-0.24, 0.24), ori_, dir_);
    // trange.x = 0.0; trange.y = 10.0;
    if(trange.x == 0.0 && trange.y == 0.0) {
      trange.x = 10000.0;
    }
    t = trange.x;
    vec2 trange2 = checkBoundingBox(vec2(-1.0, 1.0), vec2(-1.0, 1.0), vec2(-0.01, 0.0), ori, dir);
    vec2 trange3 = checkBoundingBox(vec2(-50.0, 50.0), vec2(-50.0, 50.0), vec2(0.0, 0.01), ori, dir);
    if(trange2.x != 0.0) {
      if(trange2.x < t && (trange2.x < trange3.x || trange3.x == 0.0)) {
        return vec4(5.0, ori + trange2.x * dir);
      } else {
        res = vec4(5.0, ori + trange2.x * dir);
      }
    }
    if(trange3.x != 0.0) {
      if(trange3.x < t) {
        return vec4(6.0, ori + trange3.x * dir);
      } else {
        if(trange2.x > trange3.x || trange2.x == 0.0) {
          res = vec4(6.0, ori + trange3.x * dir);
        }
      }
    }
    if(trange.x == 10000.0) {
      return res;
    }
  } else {
    t = 0.0;
  }
  float last_d = 10000.0;
  vec3 pos;
  for(int i = 0; i < MAX_STEPS; i++) {
    pos = ori + t * dir;
    vec2 d = minDist(pos);
    if(abs(d.x) < EPSILON) {
      return vec4(d.y, pos);
    }
    if(d.x < 0.0) {
        return res;
    }
    if(d.y == 4.0) {
      t += d.x * 0.2;
    } else {
      t += d.x;
    }
    if(ifBB && t > trange.y) {
      return res;
    }
  }
  return res;
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 f0, float roughness) {
  return f0 + (max(vec3(1.0 - roughness), f0) - f0) * pow(1.0 - cosTheta, 5.0);
}

vec3 lighting(vec3 ro, vec3 pos, vec3 nor, vec3 albedo, float roughness, float metallic) {
  vec3 vi = normalize(ro - pos);
  float nv = max(0.0, dot(nor, vi));

  vec3 f0 = vec3(0.04); 
  f0 = mix(f0, albedo, metallic);

  vec3 f = FresnelSchlickRoughness(nv, f0, roughness) + 0.1;
  f = smoothstep(0.2, 1.0, f);
  vec3 kD = vec3(1.0) - f;
  kD *= 1.0 - metallic;

  float diffuseE = max(dot(nor, normalize(LIGHTPos1 - pos)), 0.0);
  diffuseE += max(dot(nor, normalize(LIGHTPos2 - pos)), 0.0);
  diffuseE += max(dot(nor, normalize(LIGHTPos3 - pos)), 0.0);
  float specular = pow(dot(nor, normalize(normalize(LIGHTPos1 - pos) + vi)), 10.0);

  vec3 diffuse  = albedo * (diffuseE * 0.5 + 0.3);
  vec3 color = kD * diffuse + f * specular;

  return color;
}

vec4 render(vec3 ori, vec3 dir, vec2 p) {
  vec4 ip = rayMarch(ori, dir, true);
  vec4 col;
  vec3 nor = vec3(0.0);
  float roughness, metallic;
  vec3 albedo;

  if(ip.x > 5.5) {
    if(ip.w > 0.005) {
      nor = vec3(0.0, 0.0, 0.0);
    } else {
      nor = vec3(0.0, 0.0, -1.0);
    }
    col = texture(u_Texture2, abs(mod(vec2(ip.y * 0.1, ip.z * 0.16 + 0.5), vec2(2.0)) - vec2(1.0)));
  } else if(ip.x > 4.5) {
    if(ip.w > -0.005) {
      nor = vec3(0.0, 0.0, 1.0);
      col = paperCol;
    } else {
      nor = vec3(0.0, 0.0, -1.0);
      col = texture(u_Texture1, vec2(0.5 - ip.y * 0.5, ip.z * 0.5 + 0.5));
    }
  } else if(ip.x > 3.5) {
    vec3 pp = pencilTrans(ip.yzw, 1.0);
    float ax = abs(-2.75 - pp.x);
    float r = 1.0 - abs(2.0 * fract(30.0 * pp.x + 15.0) - 1.0) 
                    * smoothstep(0.10, 0.11, ax) * smoothstep(0.21, 0.20, ax);
    vec2 rn = random2(vec2(pp.z, 3.142), vec2(pp.x + pp.y, 2.137));
    float metalnoise = 0.1 * dot(rn, rn);
    r -= 4.0 * metalnoise;  
	  albedo = vec3(0.560, 0.570, 0.580);
   	roughness = 1.0 - 0.25 * r;
   	metallic = 1.0;
    albedo *= 1.0 - metalnoise;
    roughness += metalnoise * 4.0;
    roughness = clamp(roughness, 0.0, 1.0);
    nor = calcNormal(ip.yzw, 0.00001);
    col = vec4(lighting(ori, ip.yzw, nor, albedo, roughness, metallic), 1.0);
    nor = vec3(0.0);
  } else if(ip.x > 2.5) {
    nor = calcNormal(ip.yzw, 0.00001);
    col = vec4(0.53, 0.47, 0.42, 1.0);
  }
  else if(ip.x > 1.5) {
    nor = calcNormal(ip.yzw, 0.00001);
    vec3 pp = pencilTrans(ip.yzw, 1.0);
    if(pp.x > 2.33) {
      col = vec4(0.2, 0.2, 0.2, 1.0);
    } else if(sdHexPrism(pp, vec2(0.18, 3.0)) < 0.){
      col = vec4(0.1) + 1.2 * texture(u_Texture2, abs(mod(vec2(ip.y * 5.0, ip.z * 16.0), vec2(2.0)) - vec2(1.0)));
    } else {
      col = vec4(0.25, 0.65, 0.47, 1.0);
    }
  } else if(ip.x > 0.5) {
    nor = vec3(0.0, 1.0, 0.0);
    col = paperCol;
  } else {
    col = vec4(0.0, 0.0, 0.0, 1.0);
  }
  if(nor.x != 0.0 || nor.y != 0.0 || nor.z != 0.0) {
    float diffuse = max(dot(nor, normalize(LIGHTPos1 - ip.yzw)), 0.0);
    diffuse += max(dot(nor, normalize(LIGHTPos2 - ip.yzw)), 0.0);
    diffuse += max(dot(nor, normalize(LIGHTPos3 - ip.yzw)), 0.0);
    diffuse = diffuse * 0.3 + 0.2;
    if(ip.x > 4.5 && nor.z < 0.0) {
      float res = softshadow(ip.yzw, normalize(LIGHTPos1 - ip.yzw), 0.01, 2.0, 1.0);
      res += softshadow(ip.yzw, normalize(LIGHTPos2 - ip.yzw), 0.01, 2.0, 1.0);
      res += softshadow(ip.yzw, normalize(LIGHTPos3 - ip.yzw), 0.01, 2.0, 1.0);
      diffuse *= clamp(res, 0.3, 1.0); 
    }
    col.xyz *= diffuse;
  }
  col.xyz *= max(0.0, min(1.0, 4.0 / dot(ip.yzw, ip.yzw) - 0.05));
  return col;
}

vec3 getDir(vec3 H, float len, vec2 coord) {
  return normalize(u_Ref - u_Eye + coord.x * H + coord.y * u_Up * len);
}

void main() {
  vec3 ori = u_Eye;
  // ori = normalize(ori + vec3(0.0, 0.0, -3.0)) * 3.0;
  float len = length(u_Ref - ori);
  vec3 H = normalize(cross(u_Ref - ori, u_Up)) * len * u_Dimensions.x / u_Dimensions.y;
  vec2 delta = vec2(1.0 / u_Dimensions.x, 1.0 / u_Dimensions.y);

  vec4 color = render(ori, getDir(H, len, fs_Pos), fs_Pos);
  /*
  // AA
  color += render(ori, getDir(H, len, fs_Pos + delta * vec2(0.0, 1.0)), fs_Pos + delta * vec2(0.0, 1.0));
  color += render(ori, getDir(H, len, fs_Pos + delta * vec2(1.0, 0.0)), fs_Pos + delta * vec2(1.0, 0.0));
  color += render(ori, getDir(H, len, fs_Pos + delta * vec2(1.0, 1.0)), fs_Pos + delta * vec2(1.0, 1.0));
  color *= 0.25;
  */
  out_Col = color;
}
