#version 300 es
#define varying in
out highp vec4 pc_fragColor;
#define gl_FragColor pc_fragColor
#define gl_FragDepthEXT gl_FragDepth
#define texture2D texture
#define textureCube texture
#define texture2DProj textureProj
#define texture2DLodEXT textureLod
#define texture2DProjLodEXT textureProjLod
#define textureCubeLodEXT textureLod
#define texture2DGradEXT textureGrad
#define texture2DProjGradEXT textureProjGrad
#define textureCubeGradEXT textureGrad
precision highp float;
precision highp int;
#define HIGH_PRECISION
#define SHADER_NAME MeshStandardMaterial
#define STANDARD
#define GAMMA_FACTOR 2.0
#define USE_SHADOWMAP
#define SHADOWMAP_TYPE_BASIC
uniform mat4 viewMatrix;
uniform vec3 cameraPosition;
uniform bool isOrthographic;

vec4 LinearToLinear(in vec4 value) { return value; }

vec4 GammaToLinear(in vec4 value, in float gammaFactor) {
  return vec4(pow(value.rgb, vec3(gammaFactor)), value.a);
}

vec4 LinearToGamma(in vec4 value, in float gammaFactor) {
  return vec4(pow(value.rgb, vec3(1.0 / gammaFactor)), value.a);
}

vec4 sRGBToLinear(in vec4 value) {
  return vec4(mix(pow(value.rgb * 0.9478672986 + vec3(0.0521327014), vec3(2.4)),
                  value.rgb * 0.0773993808,
                  vec3(lessThanEqual(value.rgb, vec3(0.04045)))),
              value.a);
}

vec4 LinearTosRGB(in vec4 value) {
  return vec4(mix(pow(value.rgb, vec3(0.41666)) * 1.055 - vec3(0.055),
                  value.rgb * 12.92,
                  vec3(lessThanEqual(value.rgb, vec3(0.0031308)))),
              value.a);
}

vec4 RGBEToLinear(in vec4 value) {
  return vec4(value.rgb * exp2(value.a * 255.0 - 128.0), 1.0);
}

vec4 LinearToRGBE(in vec4 value) {
  float maxComponent = max(max(value.r, value.g), value.b);
  float fExp = clamp(ceil(log2(maxComponent)), -128.0, 127.0);
  return vec4(value.rgb / exp2(fExp), (fExp + 128.0) / 255.0);
  // return vec4( value.brg, ( 3.0 + 128.0 ) / 256.0 );
}

// reference:
// http://iwasbeingirony.blogspot.ca/2010/06/difference-between-rgbm-and-rgbd.html
vec4 RGBMToLinear(in vec4 value, in float maxRange) {
  return vec4(value.rgb * value.a * maxRange, 1.0);
}

vec4 LinearToRGBM(in vec4 value, in float maxRange) {
  float maxRGB = max(value.r, max(value.g, value.b));
  float M = clamp(maxRGB / maxRange, 0.0, 1.0);
  M = ceil(M * 255.0) / 255.0;
  return vec4(value.rgb / (M * maxRange), M);
}

// reference:
// http://iwasbeingirony.blogspot.ca/2010/06/difference-between-rgbm-and-rgbd.html
vec4 RGBDToLinear(in vec4 value, in float maxRange) {
  return vec4(value.rgb * ((maxRange / 255.0) / value.a), 1.0);
}

vec4 LinearToRGBD(in vec4 value, in float maxRange) {
  float maxRGB = max(value.r, max(value.g, value.b));
  float D = max(maxRange / maxRGB, 1.0);
  // NOTE: The implementation with min causes the shader to not compile on
  // a common Alcatel A502DL in Chrome 78/Android 8.1. Some research suggests
  // that the chipset is Mediatek MT6739 w/ IMG PowerVR GE8100 GPU.
  // D = min( floor( D ) / 255.0, 1.0 );
  D = clamp(floor(D) / 255.0, 0.0, 1.0);
  return vec4(value.rgb * (D * (255.0 / maxRange)), D);
}

// LogLuv reference:
// http://graphicrants.blogspot.ca/2009/04/rgbm-color-encoding.html

// M matrix, for encoding
const mat3 cLogLuvM = mat3(0.2209, 0.3390, 0.4184, 0.1138, 0.6780, 0.7319,
                           0.0102, 0.1130, 0.2969);
vec4 LinearToLogLuv(in vec4 value) {
  vec3 Xp_Y_XYZp = cLogLuvM * value.rgb;
  Xp_Y_XYZp = max(Xp_Y_XYZp, vec3(1e-6, 1e-6, 1e-6));
  vec4 vResult;
  vResult.xy = Xp_Y_XYZp.xy / Xp_Y_XYZp.z;
  float Le = 2.0 * log2(Xp_Y_XYZp.y) + 127.0;
  vResult.w = fract(Le);
  vResult.z = (Le - (floor(vResult.w * 255.0)) / 255.0) / 255.0;
  return vResult;
}

// Inverse M matrix, for decoding
const mat3 cLogLuvInverseM = mat3(6.0014, -2.7008, -1.7996, -1.3320, 3.1029,
                                  -5.7721, 0.3008, -1.0882, 5.6268);
vec4 LogLuvToLinear(in vec4 value) {
  float Le = value.z * 255.0 + value.w;
  vec3 Xp_Y_XYZp;
  Xp_Y_XYZp.y = exp2((Le - 127.0) / 2.0);
  Xp_Y_XYZp.z = Xp_Y_XYZp.y / value.y;
  Xp_Y_XYZp.x = value.x * Xp_Y_XYZp.z;
  vec3 vRGB = cLogLuvInverseM * Xp_Y_XYZp.rgb;
  return vec4(max(vRGB, 0.0), 1.0);
}

vec4 linearToOutputTexel(vec4 value) { return LinearToLinear(value); }
#define DEPTH_PACKING 0

#define STANDARD

#ifdef PHYSICAL
#define IOR
#define SPECULAR
#endif

uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;

#ifdef IOR
uniform float ior;
#endif

#ifdef SPECULAR
uniform float specularIntensity;
uniform vec3 specularTint;

#ifdef USE_SPECULARINTENSITYMAP
uniform sampler2D specularIntensityMap;
#endif

#ifdef USE_SPECULARTINTMAP
uniform sampler2D specularTintMap;
#endif
#endif

#ifdef USE_CLEARCOAT
uniform float clearcoat;
uniform float clearcoatRoughness;
#endif

#ifdef USE_SHEEN
uniform vec3 sheenTint;
uniform float sheenRoughness;
#endif

varying vec3 vViewPosition;

#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6

#ifndef saturate
// <tonemapping_pars_fragment> may have defined saturate() already
#define saturate(a) clamp(a, 0.0, 1.0)
#endif
#define whiteComplement(a) (1.0 - saturate(a))

float pow2(const in float x) { return x * x; }
float pow3(const in float x) { return x * x * x; }
float pow4(const in float x) {
  float x2 = x * x;
  return x2 * x2;
}
float average(const in vec3 color) { return dot(color, vec3(0.3333)); }
// expects values in the range of [0,1]x[0,1], returns values in the [0,1]
// range. do not collapse into a single function per:
// http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
highp float rand(const in vec2 uv) {
  const highp float a = 12.9898, b = 78.233, c = 43758.5453;
  highp float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
  return fract(sin(sn) * c);
}

#ifdef HIGH_PRECISION
float precisionSafeLength(vec3 v) { return length(v); }
#else
float max3(vec3 v) { return max(max(v.x, v.y), v.z); }
float precisionSafeLength(vec3 v) {
  float maxComponent = max3(abs(v));
  return length(v / maxComponent) * maxComponent;
}
#endif

struct IncidentLight {
  vec3 color;
  vec3 direction;
  bool visible;
};

struct ReflectedLight {
  vec3 directDiffuse;
  vec3 directSpecular;
  vec3 indirectDiffuse;
  vec3 indirectSpecular;
};

struct GeometricContext {
  vec3 position;
  vec3 normal;
  vec3 viewDir;
#ifdef USE_CLEARCOAT
  vec3 clearcoatNormal;
#endif
};

vec3 transformDirection(in vec3 dir, in mat4 matrix) {

  return normalize((matrix * vec4(dir, 0.0)).xyz);
}

vec3 inverseTransformDirection(in vec3 dir, in mat4 matrix) {

  // dir can be either a direction vector or a normal vector
  // upper-left 3x3 of matrix is assumed to be orthogonal

  return normalize((vec4(dir, 0.0) * matrix).xyz);
}

vec3 projectOnPlane(in vec3 point, in vec3 pointOnPlane, in vec3 planeNormal) {

  float distance = dot(planeNormal, point - pointOnPlane);

  return -distance * planeNormal + point;
}

float sideOfPlane(in vec3 point, in vec3 pointOnPlane, in vec3 planeNormal) {

  return sign(dot(point - pointOnPlane, planeNormal));
}

vec3 linePlaneIntersect(in vec3 pointOnLine, in vec3 lineDirection,
                        in vec3 pointOnPlane, in vec3 planeNormal) {

  return lineDirection * (dot(planeNormal, pointOnPlane - pointOnLine) /
                          dot(planeNormal, lineDirection)) +
         pointOnLine;
}

mat3 transposeMat3(const in mat3 m) {

  mat3 tmp;

  tmp[0] = vec3(m[0].x, m[1].x, m[2].x);
  tmp[1] = vec3(m[0].y, m[1].y, m[2].y);
  tmp[2] = vec3(m[0].z, m[1].z, m[2].z);

  return tmp;
}

// https://en.wikipedia.org/wiki/Relative_luminance
float linearToRelativeLuminance(const in vec3 color) {

  vec3 weights = vec3(0.2126, 0.7152, 0.0722);

  return dot(weights, color.rgb);
}

bool isPerspectiveMatrix(mat4 m) { return m[2][3] == -1.0; }

vec2 equirectUv(in vec3 dir) {

  // dir is assumed to be unit length

  float u = atan(dir.z, dir.x) * RECIPROCAL_PI2 + 0.5;

  float v = asin(clamp(dir.y, -1.0, 1.0)) * RECIPROCAL_PI + 0.5;

  return vec2(u, v);
}

vec3 packNormalToRGB(const in vec3 normal) {
  return normalize(normal) * 0.5 + 0.5;
}

vec3 unpackRGBToNormal(const in vec3 rgb) { return 2.0 * rgb.xyz - 1.0; }

const float PackUpscale = 256. / 255.;     // fraction -> 0..1 (including 1)
const float UnpackDownscale = 255. / 256.; // 0..1 -> fraction (excluding 1)

const vec3 PackFactors = vec3(256. * 256. * 256., 256. * 256., 256.);
const vec4 UnpackFactors = UnpackDownscale / vec4(PackFactors, 1.);

const float ShiftRight8 = 1. / 256.;

vec4 packDepthToRGBA(const in float v) {
  vec4 r = vec4(fract(v * PackFactors), v);
  r.yzw -= r.xyz * ShiftRight8; // tidy overflow
  return r * PackUpscale;
}

float unpackRGBAToDepth(const in vec4 v) { return dot(v, UnpackFactors); }

vec4 pack2HalfToRGBA(vec2 v) {
  vec4 r = vec4(v.x, fract(v.x * 255.0), v.y, fract(v.y * 255.0));
  return vec4(r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w);
}
vec2 unpackRGBATo2Half(vec4 v) {
  return vec2(v.x + (v.y / 255.0), v.z + (v.w / 255.0));
}

// NOTE: viewZ/eyeZ is < 0 when in front of the camera per OpenGL conventions

float viewZToOrthographicDepth(const in float viewZ, const in float near,
                               const in float far) {
  return (viewZ + near) / (near - far);
}
float orthographicDepthToViewZ(const in float linearClipZ, const in float near,
                               const in float far) {
  return linearClipZ * (near - far) - near;
}

float viewZToPerspectiveDepth(const in float viewZ, const in float near,
                              const in float far) {
  return ((near + viewZ) * far) / ((far - near) * viewZ);
}
float perspectiveDepthToViewZ(const in float invClipZ, const in float near,
                              const in float far) {
  return (near * far) / ((far - near) * invClipZ - far);
}

#ifdef DITHERING

// based on https://www.shadertoy.com/view/MslGR8
vec3 dithering(vec3 color) {
  // Calculate grid position
  float grid_position = rand(gl_FragCoord.xy);

  // Shift the individual colors differently, thus making it even harder to see
  // the dithering pattern
  vec3 dither_shift_RGB = vec3(0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0);

  // modify shift acording to grid position.
  dither_shift_RGB =
      mix(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position);

  // shift the color by dither_shift
  return color + dither_shift_RGB;
}

#endif

#if defined(USE_COLOR_ALPHA)

varying vec4 vColor;

#elif defined(USE_COLOR)

varying vec3 vColor;

#endif

#if (defined(USE_UV) && !defined(UVS_VERTEX_ONLY))

varying vec2 vUv;

#endif

#if defined(USE_LIGHTMAP) || defined(USE_AOMAP)

varying vec2 vUv2;

#endif

#ifdef USE_MAP

uniform sampler2D map;

#endif

#ifdef USE_ALPHAMAP

uniform sampler2D alphaMap;

#endif

#ifdef USE_ALPHATEST
uniform float alphaTest;
#endif

#ifdef USE_AOMAP

uniform sampler2D aoMap;
uniform float aoMapIntensity;

#endif

#ifdef USE_LIGHTMAP

uniform sampler2D lightMap;
uniform float lightMapIntensity;

#endif

#ifdef USE_EMISSIVEMAP

uniform sampler2D emissiveMap;

#endif

vec3 BRDF_Lambert(const in vec3 diffuseColor) {

  return RECIPROCAL_PI * diffuseColor;

} // validated

vec3 F_Schlick(const in vec3 f0, const in float f90, const in float dotVH) {

  // Original approximation by Christophe Schlick '94
  // float fresnel = pow( 1.0 - dotVH, 5.0 );

  // Optimized variant (presented by Epic at SIGGRAPH '13)
  // https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
  float fresnel = exp2((-5.55473 * dotVH - 6.98316) * dotVH);

  return f0 * (1.0 - fresnel) + (f90 * fresnel);

} // validated

// Moving Frostbite to Physically Based Rendering 3.0 - page 12, listing 2
// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
float V_GGX_SmithCorrelated(const in float alpha, const in float dotNL,
                            const in float dotNV) {

  float a2 = pow2(alpha);

  float gv = dotNL * sqrt(a2 + (1.0 - a2) * pow2(dotNV));
  float gl = dotNV * sqrt(a2 + (1.0 - a2) * pow2(dotNL));

  return 0.5 / max(gv + gl, EPSILON);
}

// Microfacet Models for Refraction through Rough Surfaces - equation (33)
// http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
// alpha is "roughness squared" in Disney’s reparameterization
float D_GGX(const in float alpha, const in float dotNH) {

  float a2 = pow2(alpha);

  float denom =
      pow2(dotNH) * (a2 - 1.0) + 1.0; // avoid alpha = 0 with dotNH = 1

  return RECIPROCAL_PI * a2 / pow2(denom);
}

// GGX Distribution, Schlick Fresnel, GGX_SmithCorrelated Visibility
vec3 BRDF_GGX(const in vec3 lightDir, const in vec3 viewDir,
              const in vec3 normal, const in vec3 f0, const in float f90,
              const in float roughness) {

  float alpha = pow2(roughness); // UE4's roughness

  vec3 halfDir = normalize(lightDir + viewDir);

  float dotNL = saturate(dot(normal, lightDir));
  float dotNV = saturate(dot(normal, viewDir));
  float dotNH = saturate(dot(normal, halfDir));
  float dotVH = saturate(dot(viewDir, halfDir));

  vec3 F = F_Schlick(f0, f90, dotVH);

  float V = V_GGX_SmithCorrelated(alpha, dotNL, dotNV);

  float D = D_GGX(alpha, dotNH);

  return F * (V * D);
}

// Rect Area Light

// Real-Time Polygonal-Light Shading with Linearly Transformed Cosines
// by Eric Heitz, Jonathan Dupuy, Stephen Hill and David Neubelt
// code: https://github.com/selfshadow/ltc_code/

vec2 LTC_Uv(const in vec3 N, const in vec3 V, const in float roughness) {

  const float LUT_SIZE = 64.0;
  const float LUT_SCALE = (LUT_SIZE - 1.0) / LUT_SIZE;
  const float LUT_BIAS = 0.5 / LUT_SIZE;

  float dotNV = saturate(dot(N, V));

  // texture parameterized by sqrt( GGX alpha ) and sqrt( 1 - cos( theta ) )
  vec2 uv = vec2(roughness, sqrt(1.0 - dotNV));

  uv = uv * LUT_SCALE + LUT_BIAS;

  return uv;
}

float LTC_ClippedSphereFormFactor(const in vec3 f) {

  // Real-Time Area Lighting: a Journey from Research to Production (p.102)
  // An approximation of the form factor of a horizon-clipped rectangle.

  float l = length(f);

  return max((l * l + f.z) / (l + 1.0), 0.0);
}

vec3 LTC_EdgeVectorFormFactor(const in vec3 v1, const in vec3 v2) {

  float x = dot(v1, v2);

  float y = abs(x);

  // rational polynomial approximation to theta / sin( theta ) / 2PI
  float a = 0.8543985 + (0.4965155 + 0.0145206 * y) * y;
  float b = 3.4175940 + (4.1616724 + y) * y;
  float v = a / b;

  float theta_sintheta =
      (x > 0.0) ? v : 0.5 * inversesqrt(max(1.0 - x * x, 1e-7)) - v;

  return cross(v1, v2) * theta_sintheta;
}

vec3 LTC_Evaluate(const in vec3 N, const in vec3 V, const in vec3 P,
                  const in mat3 mInv, const in vec3 rectCoords[4]) {

  // bail if point is on back side of plane of light
  // assumes ccw winding order of light vertices
  vec3 v1 = rectCoords[1] - rectCoords[0];
  vec3 v2 = rectCoords[3] - rectCoords[0];
  vec3 lightNormal = cross(v1, v2);

  if (dot(lightNormal, P - rectCoords[0]) < 0.0)
    return vec3(0.0);

  // construct orthonormal basis around N
  vec3 T1, T2;
  T1 = normalize(V - N * dot(V, N));
  T2 = -cross(N, T1); // negated from paper; possibly due to a different
                      // handedness of world coordinate system

  // compute transform
  mat3 mat = mInv * transposeMat3(mat3(T1, T2, N));

  // transform rect
  vec3 coords[4];
  coords[0] = mat * (rectCoords[0] - P);
  coords[1] = mat * (rectCoords[1] - P);
  coords[2] = mat * (rectCoords[2] - P);
  coords[3] = mat * (rectCoords[3] - P);

  // project rect onto sphere
  coords[0] = normalize(coords[0]);
  coords[1] = normalize(coords[1]);
  coords[2] = normalize(coords[2]);
  coords[3] = normalize(coords[3]);

  // calculate vector form factor
  vec3 vectorFormFactor = vec3(0.0);
  vectorFormFactor += LTC_EdgeVectorFormFactor(coords[0], coords[1]);
  vectorFormFactor += LTC_EdgeVectorFormFactor(coords[1], coords[2]);
  vectorFormFactor += LTC_EdgeVectorFormFactor(coords[2], coords[3]);
  vectorFormFactor += LTC_EdgeVectorFormFactor(coords[3], coords[0]);

  // adjust for horizon clipping
  float result = LTC_ClippedSphereFormFactor(vectorFormFactor);

  /*
    // alternate method of adjusting for horizon clipping (see referece)
    // refactoring required
    float len = length( vectorFormFactor );
    float z = vectorFormFactor.z / len;

    const float LUT_SIZE = 64.0;
    const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
    const float LUT_BIAS = 0.5 / LUT_SIZE;

    // tabulated horizon-clipped sphere, apparently...
    vec2 uv = vec2( z * 0.5 + 0.5, len );
    uv = uv * LUT_SCALE + LUT_BIAS;

    float scale = texture2D( ltc_2, uv ).w;

    float result = len * scale;
  */

  return vec3(result);
}

// End Rect Area Light

float G_BlinnPhong_Implicit(/* const in float dotNL, const in float dotNV */) {

  // geometry term is (n dot l)(n dot v) / 4(n dot l)(n dot v)
  return 0.25;
}

float D_BlinnPhong(const in float shininess, const in float dotNH) {

  return RECIPROCAL_PI * (shininess * 0.5 + 1.0) * pow(dotNH, shininess);
}

vec3 BRDF_BlinnPhong(const in vec3 lightDir, const in vec3 viewDir,
                     const in vec3 normal, const in vec3 specularColor,
                     const in float shininess) {

  vec3 halfDir = normalize(lightDir + viewDir);

  float dotNH = saturate(dot(normal, halfDir));
  float dotVH = saturate(dot(viewDir, halfDir));

  vec3 F = F_Schlick(specularColor, 1.0, dotVH);

  float G = G_BlinnPhong_Implicit(/* dotNL, dotNV */);

  float D = D_BlinnPhong(shininess, dotNH);

  return F * (G * D);

} // validated

#if defined(USE_SHEEN)

// https://github.com/google/filament/blob/master/shaders/src/brdf.fs
float D_Charlie(float roughness, float dotNH) {

  float alpha = pow2(roughness);

  // Estevez and Kulla 2017, "Production Friendly Microfacet Sheen BRDF"
  float invAlpha = 1.0 / alpha;
  float cos2h = dotNH * dotNH;
  float sin2h =
      max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16

  return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * PI);
}

// https://github.com/google/filament/blob/master/shaders/src/brdf.fs
float V_Neubelt(float dotNV, float dotNL) {

  // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The
  // Order: 1886"
  return saturate(1.0 / (4.0 * (dotNL + dotNV - dotNL * dotNV)));
}

vec3 BRDF_Sheen(const in vec3 lightDir, const in vec3 viewDir,
                const in vec3 normal, vec3 sheenTint,
                const in float sheenRoughness) {

  vec3 halfDir = normalize(lightDir + viewDir);

  float dotNL = saturate(dot(normal, lightDir));
  float dotNV = saturate(dot(normal, viewDir));
  float dotNH = saturate(dot(normal, halfDir));

  float D = D_Charlie(sheenRoughness, dotNH);
  float V = V_Neubelt(dotNV, dotNL);

  return sheenTint * (D * V);
}

#endif

#ifdef ENVMAP_TYPE_CUBE_UV

#define cubeUV_maxMipLevel 8.0
#define cubeUV_minMipLevel 4.0
#define cubeUV_maxTileSize 256.0
#define cubeUV_minTileSize 16.0

// These shader functions convert between the UV coordinates of a single face of
// a cubemap, the 0-5 integer index of a cube face, and the direction vector for
// sampling a textureCube (not generally normalized ).

float getFace(vec3 direction) {

  vec3 absDirection = abs(direction);

  float face = -1.0;

  if (absDirection.x > absDirection.z) {

    if (absDirection.x > absDirection.y)

      face = direction.x > 0.0 ? 0.0 : 3.0;

    else

      face = direction.y > 0.0 ? 1.0 : 4.0;

  } else {

    if (absDirection.z > absDirection.y)

      face = direction.z > 0.0 ? 2.0 : 5.0;

    else

      face = direction.y > 0.0 ? 1.0 : 4.0;
  }

  return face;
}

// RH coordinate system; PMREM face-indexing convention
vec2 getUV(vec3 direction, float face) {

  vec2 uv;

  if (face == 0.0) {

    uv = vec2(direction.z, direction.y) / abs(direction.x); // pos x

  } else if (face == 1.0) {

    uv = vec2(-direction.x, -direction.z) / abs(direction.y); // pos y

  } else if (face == 2.0) {

    uv = vec2(-direction.x, direction.y) / abs(direction.z); // pos z

  } else if (face == 3.0) {

    uv = vec2(-direction.z, direction.y) / abs(direction.x); // neg x

  } else if (face == 4.0) {

    uv = vec2(-direction.x, direction.z) / abs(direction.y); // neg y

  } else {

    uv = vec2(direction.x, direction.y) / abs(direction.z); // neg z
  }

  return 0.5 * (uv + 1.0);
}

vec3 bilinearCubeUV(sampler2D envMap, vec3 direction, float mipInt) {

  float face = getFace(direction);

  float filterInt = max(cubeUV_minMipLevel - mipInt, 0.0);

  mipInt = max(mipInt, cubeUV_minMipLevel);

  float faceSize = exp2(mipInt);

  float texelSize = 1.0 / (3.0 * cubeUV_maxTileSize);

  vec2 uv = getUV(direction, face) * (faceSize - 1.0);

  vec2 f = fract(uv);

  uv += 0.5 - f;

  if (face > 2.0) {

    uv.y += faceSize;

    face -= 3.0;
  }

  uv.x += face * faceSize;

  if (mipInt < cubeUV_maxMipLevel) {

    uv.y += 2.0 * cubeUV_maxTileSize;
  }

  uv.y += filterInt * 2.0 * cubeUV_minTileSize;

  uv.x += 3.0 * max(0.0, cubeUV_maxTileSize - 2.0 * faceSize);

  uv *= texelSize;

  vec3 tl = envMapTexelToLinear(texture2D(envMap, uv)).rgb;

  uv.x += texelSize;

  vec3 tr = envMapTexelToLinear(texture2D(envMap, uv)).rgb;

  uv.y += texelSize;

  vec3 br = envMapTexelToLinear(texture2D(envMap, uv)).rgb;

  uv.x -= texelSize;

  vec3 bl = envMapTexelToLinear(texture2D(envMap, uv)).rgb;

  vec3 tm = mix(tl, tr, f.x);

  vec3 bm = mix(bl, br, f.x);

  return mix(tm, bm, f.y);
}

// These defines must match with PMREMGenerator

#define r0 1.0
#define v0 0.339
#define m0 -2.0
#define r1 0.8
#define v1 0.276
#define m1 -1.0
#define r4 0.4
#define v4 0.046
#define m4 2.0
#define r5 0.305
#define v5 0.016
#define m5 3.0
#define r6 0.21
#define v6 0.0038
#define m6 4.0

float roughnessToMip(float roughness) {

  float mip = 0.0;

  if (roughness >= r1) {

    mip = (r0 - roughness) * (m1 - m0) / (r0 - r1) + m0;

  } else if (roughness >= r4) {

    mip = (r1 - roughness) * (m4 - m1) / (r1 - r4) + m1;

  } else if (roughness >= r5) {

    mip = (r4 - roughness) * (m5 - m4) / (r4 - r5) + m4;

  } else if (roughness >= r6) {

    mip = (r5 - roughness) * (m6 - m5) / (r5 - r6) + m5;

  } else {

    mip = -2.0 * log2(1.16 * roughness); // 1.16 = 1.79^0.25
  }

  return mip;
}

vec4 textureCubeUV(sampler2D envMap, vec3 sampleDir, float roughness) {

  float mip = clamp(roughnessToMip(roughness), m0, cubeUV_maxMipLevel);

  float mipF = fract(mip);

  float mipInt = floor(mip);

  vec3 color0 = bilinearCubeUV(envMap, sampleDir, mipInt);

  if (mipF == 0.0) {

    return vec4(color0, 1.0);

  } else {

    vec3 color1 = bilinearCubeUV(envMap, sampleDir, mipInt + 1.0);

    return vec4(mix(color0, color1, mipF), 1.0);
  }
}

#endif

#ifdef USE_ENVMAP

uniform float envMapIntensity;
uniform float flipEnvMap;
uniform int maxMipLevel;

#ifdef ENVMAP_TYPE_CUBE
uniform samplerCube envMap;
#else
uniform sampler2D envMap;
#endif

#endif

#if defined(USE_ENVMAP)

#ifdef ENVMAP_MODE_REFRACTION

uniform float refractionRatio;

#endif

vec3 getLightProbeIndirectIrradiance(const in GeometricContext geometry,
                                     const in int maxMIPLevel) {

#if defined(ENVMAP_TYPE_CUBE_UV)

  vec3 worldNormal = inverseTransformDirection(geometry.normal, viewMatrix);

  vec4 envMapColor = textureCubeUV(envMap, worldNormal, 1.0);

  return PI * envMapColor.rgb * envMapIntensity;

#else

  return vec3(0.0);

#endif
}

vec3 getLightProbeIndirectRadiance(const in vec3 viewDir, const in vec3 normal,
                                   const in float roughness,
                                   const in int maxMIPLevel) {

#if defined(ENVMAP_TYPE_CUBE_UV)

  vec3 reflectVec;

#ifdef ENVMAP_MODE_REFLECTION

  reflectVec = reflect(-viewDir, normal);

  // Mixing the reflection with the normal is more accurate and keeps rough
  // objects from gathering light from behind their tangent plane.
  reflectVec = normalize(mix(reflectVec, normal, roughness * roughness));

#else

  reflectVec = refract(-viewDir, normal, refractionRatio);

#endif

  reflectVec = inverseTransformDirection(reflectVec, viewMatrix);

  vec4 envMapColor = textureCubeUV(envMap, reflectVec, roughness);

  return envMapColor.rgb * envMapIntensity;

#else

  return vec3(0.0);

#endif
}

#endif

#ifdef USE_FOG

uniform vec3 fogColor;
varying float vFogDepth;

#ifdef FOG_EXP2

uniform float fogDensity;

#else

uniform float fogNear;
uniform float fogFar;

#endif

#endif

uniform bool receiveShadow;
uniform vec3 ambientLightColor;
uniform vec3 lightProbe[9];

// get the irradiance (radiance convolved with cosine lobe) at the point
// 'normal' on the unit sphere source:
// https://graphics.stanford.edu/papers/envmap/envmap.pdf
vec3 shGetIrradianceAt(in vec3 normal, in vec3 shCoefficients[9]) {

  // normal is assumed to have unit length

  float x = normal.x, y = normal.y, z = normal.z;

  // band 0
  vec3 result = shCoefficients[0] * 0.886227;

  // band 1
  result += shCoefficients[1] * 2.0 * 0.511664 * y;
  result += shCoefficients[2] * 2.0 * 0.511664 * z;
  result += shCoefficients[3] * 2.0 * 0.511664 * x;

  // band 2
  result += shCoefficients[4] * 2.0 * 0.429043 * x * y;
  result += shCoefficients[5] * 2.0 * 0.429043 * y * z;
  result += shCoefficients[6] * (0.743125 * z * z - 0.247708);
  result += shCoefficients[7] * 2.0 * 0.429043 * x * z;
  result += shCoefficients[8] * 0.429043 * (x * x - y * y);

  return result;
}

vec3 getLightProbeIrradiance(const in vec3 lightProbe[9],
                             const in vec3 normal) {

  vec3 worldNormal = inverseTransformDirection(normal, viewMatrix);

  vec3 irradiance = shGetIrradianceAt(worldNormal, lightProbe);

  return irradiance;
}

vec3 getAmbientLightIrradiance(const in vec3 ambientLightColor) {

  vec3 irradiance = ambientLightColor;

  return irradiance;
}

float getDistanceAttenuation(const in float lightDistance,
                             const in float cutoffDistance,
                             const in float decayExponent) {

#if defined(PHYSICALLY_CORRECT_LIGHTS)

  // based upon Frostbite 3 Moving to Physically-based Rendering
  // page 32, equation 26: E[window1]
  // https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
  float distanceFalloff = 1.0 / max(pow(lightDistance, decayExponent), 0.01);

  if (cutoffDistance > 0.0) {

    distanceFalloff *=
        pow2(saturate(1.0 - pow4(lightDistance / cutoffDistance)));
  }

  return distanceFalloff;

#else

  if (cutoffDistance > 0.0 && decayExponent > 0.0) {

    return pow(saturate(-lightDistance / cutoffDistance + 1.0), decayExponent);
  }

  return 1.0;

#endif
}

float getSpotAttenuation(const in float coneCosine,
                         const in float penumbraCosine,
                         const in float angleCosine) {

  return smoothstep(coneCosine, penumbraCosine, angleCosine);
}

#if 0 > 0
      
      	struct DirectionalLight {
      		vec3 direction;
      		vec3 color;
      	};
      
      	uniform DirectionalLight directionalLights[ 0 ];
      
      	void getDirectionalLightInfo( const in DirectionalLight directionalLight, const in GeometricContext geometry, out IncidentLight light ) {
      
      		light.color = directionalLight.color;
      		light.direction = directionalLight.direction;
      		light.visible = true;
      
      	}

#endif

#if 0 > 0
      
      	struct PointLight {
      		vec3 position;
      		vec3 color;
      		float distance;
      		float decay;
      	};
      
      	uniform PointLight pointLights[ 0 ];
      
      	// light is an out parameter as having it as a return value caused compiler errors on some devices
      	void getPointLightInfo( const in PointLight pointLight, const in GeometricContext geometry, out IncidentLight light ) {
      
      		vec3 lVector = pointLight.position - geometry.position;
      
      		light.direction = normalize( lVector );
      
      		float lightDistance = length( lVector );
      
      		light.color = pointLight.color;
      		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
      		light.visible = ( light.color != vec3( 0.0 ) );
      
      	}

#endif

#if 1 > 0

struct SpotLight {
  vec3 position;
  vec3 direction;
  vec3 color;
  float distance;
  float decay;
  float coneCos;
  float penumbraCos;
};

uniform SpotLight spotLights[1];

// light is an out parameter as having it as a return value caused compiler
// errors on some devices
void getSpotLightInfo(const in SpotLight spotLight,
                      const in GeometricContext geometry,
                      out IncidentLight light) {

  vec3 lVector = spotLight.position - geometry.position;

  light.direction = normalize(lVector);

  float angleCos = dot(light.direction, spotLight.direction);

  float spotAttenuation =
      getSpotAttenuation(spotLight.coneCos, spotLight.penumbraCos, angleCos);

  if (spotAttenuation > 0.0) {

    float lightDistance = length(lVector);

    light.color = spotLight.color * spotAttenuation;
    light.color *= getDistanceAttenuation(lightDistance, spotLight.distance,
                                          spotLight.decay);
    light.visible = (light.color != vec3(0.0));

  } else {

    light.color = vec3(0.0);
    light.visible = false;
  }
}

#endif

#if 0 > 0
      
      	struct RectAreaLight {
      		vec3 color;
      		vec3 position;
      		vec3 halfWidth;
      		vec3 halfHeight;
      	};
      
      	// Pre-computed values of LinearTransformedCosine approximation of BRDF
      	// BRDF approximation Texture is 64x64
      	uniform sampler2D ltc_1; // RGBA Float
      	uniform sampler2D ltc_2; // RGBA Float
      
      	uniform RectAreaLight rectAreaLights[ 0 ];

#endif

#if 0 > 0
      
      	struct HemisphereLight {
      		vec3 direction;
      		vec3 skyColor;
      		vec3 groundColor;
      	};
      
      	uniform HemisphereLight hemisphereLights[ 0 ];
      
      	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
      
      		float dotNL = dot( normal, hemiLight.direction );
      		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
      
      		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
      
      		return irradiance;
      
      	}

#endif

#ifndef FLAT_SHADED

varying vec3 vNormal;

#ifdef USE_TANGENT

varying vec3 vTangent;
varying vec3 vBitangent;

#endif

#endif

struct PhysicalMaterial {

  vec3 diffuseColor;
  float roughness;
  vec3 specularColor;
  float specularF90;

#ifdef USE_CLEARCOAT
  float clearcoat;
  float clearcoatRoughness;
  vec3 clearcoatF0;
  float clearcoatF90;
#endif

#ifdef USE_SHEEN
  vec3 sheenTint;
  float sheenRoughness;
#endif
};

// temporary
vec3 clearcoatSpecular = vec3(0.0);

// Analytical approximation of the DFG LUT, one half of the
// split-sum approximation used in indirect specular lighting.
// via 'environmentBRDF' from "Physically Based Shading on Mobile"
// https://www.unrealengine.com/blog/physically-based-shading-on-mobile
vec2 DFGApprox(const in vec3 normal, const in vec3 viewDir,
               const in float roughness) {

  float dotNV = saturate(dot(normal, viewDir));

  const vec4 c0 = vec4(-1, -0.0275, -0.572, 0.022);

  const vec4 c1 = vec4(1, 0.0425, 1.04, -0.04);

  vec4 r = roughness * c0 + c1;

  float a004 = min(r.x * r.x, exp2(-9.28 * dotNV)) * r.x + r.y;

  vec2 fab = vec2(-1.04, 1.04) * a004 + r.zw;

  return fab;
}

vec3 EnvironmentBRDF(const in vec3 normal, const in vec3 viewDir,
                     const in vec3 specularColor, const in float specularF90,
                     const in float roughness) {

  vec2 fab = DFGApprox(normal, viewDir, roughness);

  return specularColor * fab.x + specularF90 * fab.y;
}

// Fdez-Agüera's "Multiple-Scattering Microfacet Model for Real-Time Image Based
// Lighting" Approximates multiscattering in order to preserve energy.
// http://www.jcgt.org/published/0008/01/03/
void computeMultiscattering(const in vec3 normal, const in vec3 viewDir,
                            const in vec3 specularColor,
                            const in float specularF90,
                            const in float roughness, inout vec3 singleScatter,
                            inout vec3 multiScatter) {

  vec2 fab = DFGApprox(normal, viewDir, roughness);

  vec3 FssEss = specularColor * fab.x + specularF90 * fab.y;

  float Ess = fab.x + fab.y;
  float Ems = 1.0 - Ess;

  vec3 Favg = specularColor + (1.0 - specularColor) * 0.047619; // 1/21
  vec3 Fms = FssEss * Favg / (1.0 - Ems * Favg);

  singleScatter += FssEss;
  multiScatter += Fms * Ems;
}

#if 0 > 0
      
      	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in GeometricContext geometry, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
      
      		vec3 normal = geometry.normal;
      		vec3 viewDir = geometry.viewDir;
      		vec3 position = geometry.position;
      		vec3 lightPos = rectAreaLight.position;
      		vec3 halfWidth = rectAreaLight.halfWidth;
      		vec3 halfHeight = rectAreaLight.halfHeight;
      		vec3 lightColor = rectAreaLight.color;
      		float roughness = material.roughness;
      
      		vec3 rectCoords[ 4 ];
      		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight; // counterclockwise; light shines in local neg z direction
      		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
      		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
      		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
      
      		vec2 uv = LTC_Uv( normal, viewDir, roughness );
      
      		vec4 t1 = texture2D( ltc_1, uv );
      		vec4 t2 = texture2D( ltc_2, uv );
      
      		mat3 mInv = mat3(
      			vec3( t1.x, 0, t1.y ),
      			vec3(    0, 1,    0 ),
      			vec3( t1.z, 0, t1.w )
      		);
      
      		// LTC Fresnel Approximation by Stephen Hill
      		// http://blog.selfshadow.com/publications/s2016-advances/s2016_ltc_fresnel.pdf
      		vec3 fresnel = ( material.specularColor * t2.x + ( vec3( 1.0 ) - material.specularColor ) * t2.y );
      
      		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
      
      		reflectedLight.directDiffuse += lightColor * material.diffuseColor * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
      
      	}

#endif

void RE_Direct_Physical(const in IncidentLight directLight,
                        const in GeometricContext geometry,
                        const in PhysicalMaterial material,
                        inout ReflectedLight reflectedLight) {

  float dotNL = saturate(dot(geometry.normal, directLight.direction));

  vec3 irradiance = dotNL * directLight.color;

#ifdef USE_CLEARCOAT

  float dotNLcc =
      saturate(dot(geometry.clearcoatNormal, directLight.direction));

  vec3 ccIrradiance = dotNLcc * directLight.color;

  clearcoatSpecular +=
      ccIrradiance * BRDF_GGX(directLight.direction, geometry.viewDir,
                              geometry.clearcoatNormal, material.clearcoatF0,
                              material.clearcoatF90,
                              material.clearcoatRoughness);

#endif

#ifdef USE_SHEEN

  reflectedLight.directSpecular +=
      irradiance * BRDF_Sheen(directLight.direction, geometry.viewDir,
                              geometry.normal, material.sheenTint,
                              material.sheenRoughness);

#endif

  reflectedLight.directSpecular +=
      irradiance * BRDF_GGX(directLight.direction, geometry.viewDir,
                            geometry.normal, material.specularColor,
                            material.specularF90, material.roughness);

  reflectedLight.directDiffuse +=
      irradiance * BRDF_Lambert(material.diffuseColor);
}

void RE_IndirectDiffuse_Physical(const in vec3 irradiance,
                                 const in GeometricContext geometry,
                                 const in PhysicalMaterial material,
                                 inout ReflectedLight reflectedLight) {

  reflectedLight.indirectDiffuse +=
      irradiance * BRDF_Lambert(material.diffuseColor);
}

void RE_IndirectSpecular_Physical(const in vec3 radiance,
                                  const in vec3 irradiance,
                                  const in vec3 clearcoatRadiance,
                                  const in GeometricContext geometry,
                                  const in PhysicalMaterial material,
                                  inout ReflectedLight reflectedLight) {

#ifdef USE_CLEARCOAT

  clearcoatSpecular +=
      clearcoatRadiance *
      EnvironmentBRDF(geometry.clearcoatNormal, geometry.viewDir,
                      material.clearcoatF0, material.clearcoatF90,
                      material.clearcoatRoughness);

#endif

  // Both indirect specular and indirect diffuse light accumulate here

  vec3 singleScattering = vec3(0.0);
  vec3 multiScattering = vec3(0.0);
  vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;

  computeMultiscattering(geometry.normal, geometry.viewDir,
                         material.specularColor, material.specularF90,
                         material.roughness, singleScattering, multiScattering);

  vec3 diffuse =
      material.diffuseColor * (1.0 - (singleScattering + multiScattering));

  reflectedLight.indirectSpecular += radiance * singleScattering;
  reflectedLight.indirectSpecular += multiScattering * cosineWeightedIrradiance;

  reflectedLight.indirectDiffuse += diffuse * cosineWeightedIrradiance;
}

#define RE_Direct RE_Direct_Physical
#define RE_Direct_RectArea RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular RE_IndirectSpecular_Physical

// ref:
// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
float computeSpecularOcclusion(const in float dotNV,
                               const in float ambientOcclusion,
                               const in float roughness) {

  return saturate(pow(dotNV + ambientOcclusion, exp2(-16.0 * roughness - 1.0)) -
                  1.0 + ambientOcclusion);
}

#ifdef USE_TRANSMISSION

// Transmission code is based on glTF-Sampler-Viewer
// https://github.com/KhronosGroup/glTF-Sample-Viewer

uniform float transmission;
uniform float thickness;
uniform float attenuationDistance;
uniform vec3 attenuationTint;

#ifdef USE_TRANSMISSIONMAP

uniform sampler2D transmissionMap;

#endif

#ifdef USE_THICKNESSMAP

uniform sampler2D thicknessMap;

#endif

uniform vec2 transmissionSamplerSize;
uniform sampler2D transmissionSamplerMap;

uniform mat4 modelMatrix;
uniform mat4 projectionMatrix;

varying vec3 vWorldPosition;

vec3 getVolumeTransmissionRay(vec3 n, vec3 v, float thickness, float ior,
                              mat4 modelMatrix) {

  // Direction of refracted light.
  vec3 refractionVector = refract(-v, normalize(n), 1.0 / ior);

  // Compute rotation-independant scaling of the model matrix.
  vec3 modelScale;
  modelScale.x = length(vec3(modelMatrix[0].xyz));
  modelScale.y = length(vec3(modelMatrix[1].xyz));
  modelScale.z = length(vec3(modelMatrix[2].xyz));

  // The thickness is specified in local space.
  return normalize(refractionVector) * thickness * modelScale;
}

float applyIorToRoughness(float roughness, float ior) {

  // Scale roughness with IOR so that an IOR of 1.0 results in no microfacet
  // refraction and an IOR of 1.5 results in the default amount of microfacet
  // refraction.
  return roughness * clamp(ior * 2.0 - 2.0, 0.0, 1.0);
}

vec3 getTransmissionSample(vec2 fragCoord, float roughness, float ior) {

  float framebufferLod =
      log2(transmissionSamplerSize.x) * applyIorToRoughness(roughness, ior);

#ifdef TEXTURE_LOD_EXT

  return texture2DLodEXT(transmissionSamplerMap, fragCoord.xy, framebufferLod)
      .rgb;

#else

  return texture2D(transmissionSamplerMap, fragCoord.xy, framebufferLod).rgb;

#endif
}

vec3 applyVolumeAttenuation(vec3 radiance, float transmissionDistance,
                            vec3 attenuationColor, float attenuationDistance) {

  if (attenuationDistance == 0.0) {

    // Attenuation distance is +∞ (which we indicate by zero), i.e. the
    // transmitted color is not attenuated at all.
    return radiance;

  } else {

    // Compute light attenuation using Beer's law.
    vec3 attenuationCoefficient = -log(attenuationColor) / attenuationDistance;
    vec3 transmittance =
        exp(-attenuationCoefficient * transmissionDistance); // Beer's law
    return transmittance * radiance;
  }
}

vec3 getIBLVolumeRefraction(vec3 n, vec3 v, float roughness, vec3 diffuseColor,
                            vec3 specularColor, float specularF90,
                            vec3 position, mat4 modelMatrix, mat4 viewMatrix,
                            mat4 projMatrix, float ior, float thickness,
                            vec3 attenuationColor, float attenuationDistance) {

  vec3 transmissionRay =
      getVolumeTransmissionRay(n, v, thickness, ior, modelMatrix);
  vec3 refractedRayExit = position + transmissionRay;

  // Project refracted vector on the framebuffer, while mapping to normalized
  // device coordinates.
  vec4 ndcPos = projMatrix * viewMatrix * vec4(refractedRayExit, 1.0);
  vec2 refractionCoords = ndcPos.xy / ndcPos.w;
  refractionCoords += 1.0;
  refractionCoords /= 2.0;

  // Sample framebuffer to get pixel the refracted ray hits.
  vec3 transmittedLight =
      getTransmissionSample(refractionCoords, roughness, ior);

  vec3 attenuatedColor =
      applyVolumeAttenuation(transmittedLight, length(transmissionRay),
                             attenuationColor, attenuationDistance);

  // Get the specular component.
  vec3 F = EnvironmentBRDF(n, v, specularColor, specularF90, roughness);

  return (1.0 - F) * attenuatedColor * diffuseColor;
}
#endif

#ifdef USE_SHADOWMAP

#if 0 > 0
      
      		uniform sampler2D directionalShadowMap[ 0 ];
      		varying vec4 vDirectionalShadowCoord[ 0 ];
      
      		struct DirectionalLightShadow {
      			float shadowBias;
      			float shadowNormalBias;
      			float shadowRadius;
      			vec2 shadowMapSize;
      		};
      
      		uniform DirectionalLightShadow directionalLightShadows[ 0 ];

#endif

#if 1 > 0

uniform sampler2D spotShadowMap[1];
varying vec4 vSpotShadowCoord[1];

struct SpotLightShadow {
  float shadowBias;
  float shadowNormalBias;
  float shadowRadius;
  vec2 shadowMapSize;
};

uniform SpotLightShadow spotLightShadows[1];

#endif

#if 0 > 0
      
      		uniform sampler2D pointShadowMap[ 0 ];
      		varying vec4 vPointShadowCoord[ 0 ];
      
      		struct PointLightShadow {
      			float shadowBias;
      			float shadowNormalBias;
      			float shadowRadius;
      			vec2 shadowMapSize;
      			float shadowCameraNear;
      			float shadowCameraFar;
      		};
      
      		uniform PointLightShadow pointLightShadows[ 0 ];

#endif

/*
#if 0 > 0

        // TODO (abelnation): create uniforms for area light shadows

#endif
*/

float texture2DCompare(sampler2D depths, vec2 uv, float compare) {

  return step(compare, unpackRGBAToDepth(texture2D(depths, uv)));
}

vec2 texture2DDistribution(sampler2D shadow, vec2 uv) {

  return unpackRGBATo2Half(texture2D(shadow, uv));
}

float VSMShadow(sampler2D shadow, vec2 uv, float compare) {

  float occlusion = 1.0;

  vec2 distribution = texture2DDistribution(shadow, uv);

  float hard_shadow = step(compare, distribution.x); // Hard Shadow

  if (hard_shadow != 1.0) {

    float distance = compare - distribution.x;
    float variance = max(0.00000, distribution.y * distribution.y);
    float softness_probability =
        variance / (variance + distance * distance); // Chebeyshevs inequality
    softness_probability = clamp((softness_probability - 0.3) / (0.95 - 0.3),
                                 0.0, 1.0); // 0.3 reduces light bleed
    occlusion = clamp(max(hard_shadow, softness_probability), 0.0, 1.0);
  }
  return occlusion;
}

float getShadow(sampler2D shadowMap, vec2 shadowMapSize, float shadowBias,
                float shadowRadius, vec4 shadowCoord) {

  float shadow = 1.0;

  shadowCoord.xyz /= shadowCoord.w;
  shadowCoord.z += shadowBias;

  // if ( something && something ) breaks ATI OpenGL shader compiler
  // if ( all( something, something ) ) using this instead

  bvec4 inFrustumVec = bvec4(shadowCoord.x >= 0.0, shadowCoord.x <= 1.0,
                             shadowCoord.y >= 0.0, shadowCoord.y <= 1.0);
  bool inFrustum = all(inFrustumVec);

  bvec2 frustumTestVec = bvec2(inFrustum, shadowCoord.z <= 1.0);

  bool frustumTest = all(frustumTestVec);

  if (frustumTest) {

#if defined(SHADOWMAP_TYPE_PCF)

    vec2 texelSize = vec2(1.0) / shadowMapSize;

    float dx0 = -texelSize.x * shadowRadius;
    float dy0 = -texelSize.y * shadowRadius;
    float dx1 = +texelSize.x * shadowRadius;
    float dy1 = +texelSize.y * shadowRadius;
    float dx2 = dx0 / 2.0;
    float dy2 = dy0 / 2.0;
    float dx3 = dx1 / 2.0;
    float dy3 = dy1 / 2.0;

    shadow = (texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx0, dy0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(0.0, dy0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx1, dy0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx2, dy2),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(0.0, dy2),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx3, dy2),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx0, 0.0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx2, 0.0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy, shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx3, 0.0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx1, 0.0),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx2, dy3),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(0.0, dy3),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx3, dy3),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx0, dy1),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(0.0, dy1),
                               shadowCoord.z) +
              texture2DCompare(shadowMap, shadowCoord.xy + vec2(dx1, dy1),
                               shadowCoord.z)) *
             (1.0 / 17.0);

#elif defined(SHADOWMAP_TYPE_PCF_SOFT)

    vec2 texelSize = vec2(1.0) / shadowMapSize;
    float dx = texelSize.x;
    float dy = texelSize.y;

    vec2 uv = shadowCoord.xy;
    vec2 f = fract(uv * shadowMapSize + 0.5);
    uv -= f * texelSize;

    shadow =
        (texture2DCompare(shadowMap, uv, shadowCoord.z) +
         texture2DCompare(shadowMap, uv + vec2(dx, 0.0), shadowCoord.z) +
         texture2DCompare(shadowMap, uv + vec2(0.0, dy), shadowCoord.z) +
         texture2DCompare(shadowMap, uv + texelSize, shadowCoord.z) +
         mix(texture2DCompare(shadowMap, uv + vec2(-dx, 0.0), shadowCoord.z),
             texture2DCompare(shadowMap, uv + vec2(2.0 * dx, 0.0),
                              shadowCoord.z),
             f.x) +
         mix(texture2DCompare(shadowMap, uv + vec2(-dx, dy), shadowCoord.z),
             texture2DCompare(shadowMap, uv + vec2(2.0 * dx, dy),
                              shadowCoord.z),
             f.x) +
         mix(texture2DCompare(shadowMap, uv + vec2(0.0, -dy), shadowCoord.z),
             texture2DCompare(shadowMap, uv + vec2(0.0, 2.0 * dy),
                              shadowCoord.z),
             f.y) +
         mix(texture2DCompare(shadowMap, uv + vec2(dx, -dy), shadowCoord.z),
             texture2DCompare(shadowMap, uv + vec2(dx, 2.0 * dy),
                              shadowCoord.z),
             f.y) +
         mix(mix(texture2DCompare(shadowMap, uv + vec2(-dx, -dy),
                                  shadowCoord.z),
                 texture2DCompare(shadowMap, uv + vec2(2.0 * dx, -dy),
                                  shadowCoord.z),
                 f.x),
             mix(texture2DCompare(shadowMap, uv + vec2(-dx, 2.0 * dy),
                                  shadowCoord.z),
                 texture2DCompare(shadowMap, uv + vec2(2.0 * dx, 2.0 * dy),
                                  shadowCoord.z),
                 f.x),
             f.y)) *
        (1.0 / 9.0);

#elif defined(SHADOWMAP_TYPE_VSM)

    shadow = VSMShadow(shadowMap, shadowCoord.xy, shadowCoord.z);

#else // no percentage-closer filtering:

    shadow = texture2DCompare(shadowMap, shadowCoord.xy, shadowCoord.z);

#endif
  }

  return shadow;
}

// cubeToUV() maps a 3D direction vector suitable for cube texture mapping to a
// 2D vector suitable for 2D texture mapping. This code uses the following
// layout for the 2D texture:
//
// xzXZ
//  y Y
//
// Y - Positive y direction
// y - Negative y direction
// X - Positive x direction
// x - Negative x direction
// Z - Positive z direction
// z - Negative z direction
//
// Source and test bed:
// https://gist.github.com/tschw/da10c43c467ce8afd0c4

vec2 cubeToUV(vec3 v, float texelSizeY) {

  // Number of texels to avoid at the edge of each square

  vec3 absV = abs(v);

  // Intersect unit cube

  float scaleToCube = 1.0 / max(absV.x, max(absV.y, absV.z));
  absV *= scaleToCube;

  // Apply scale to avoid seams

  // two texels less per square (one texel will do for NEAREST)
  v *= scaleToCube * (1.0 - 2.0 * texelSizeY);

  // Unwrap

  // space: -1 ... 1 range for each square
  //
  // #X##		dim    := ( 4 , 2 )
  //  # #		center := ( 1 , 1 )

  vec2 planar = v.xy;

  float almostATexel = 1.5 * texelSizeY;
  float almostOne = 1.0 - almostATexel;

  if (absV.z >= almostOne) {

    if (v.z > 0.0)
      planar.x = 4.0 - v.x;

  } else if (absV.x >= almostOne) {

    float signX = sign(v.x);
    planar.x = v.z * signX + 2.0 * signX;

  } else if (absV.y >= almostOne) {

    float signY = sign(v.y);
    planar.x = v.x + 2.0 * signY + 2.0;
    planar.y = v.z * signY - 2.0;
  }

  // Transform to UV space

  // scale := 0.5 / dim
  // translate := ( center + 0.5 ) / dim
  return vec2(0.125, 0.25) * planar + vec2(0.375, 0.75);
}

float getPointShadow(sampler2D shadowMap, vec2 shadowMapSize, float shadowBias,
                     float shadowRadius, vec4 shadowCoord,
                     float shadowCameraNear, float shadowCameraFar) {

  vec2 texelSize = vec2(1.0) / (shadowMapSize * vec2(4.0, 2.0));

  // for point lights, the uniform @vShadowCoord is re-purposed to hold
  // the vector from the light to the world-space position of the fragment.
  vec3 lightToPosition = shadowCoord.xyz;

  // dp = normalized distance from light to fragment position
  float dp = (length(lightToPosition) - shadowCameraNear) /
             (shadowCameraFar - shadowCameraNear); // need to clamp?
  dp += shadowBias;

  // bd3D = base direction 3D
  vec3 bd3D = normalize(lightToPosition);

#if defined(SHADOWMAP_TYPE_PCF) || defined(SHADOWMAP_TYPE_PCF_SOFT) ||         \
    defined(SHADOWMAP_TYPE_VSM)

  vec2 offset = vec2(-1, 1) * shadowRadius * texelSize.y;

  return (texture2DCompare(shadowMap, cubeToUV(bd3D + offset.xyy, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.yyy, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.xyx, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.yyx, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D, texelSize.y), dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.xxy, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.yxy, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.xxx, texelSize.y),
                           dp) +
          texture2DCompare(shadowMap, cubeToUV(bd3D + offset.yxx, texelSize.y),
                           dp)) *
         (1.0 / 9.0);

#else // no percentage-closer filtering

  return texture2DCompare(shadowMap, cubeToUV(bd3D, texelSize.y), dp);

#endif
}

#endif

#ifdef USE_BUMPMAP

uniform sampler2D bumpMap;
uniform float bumpScale;

// Bump Mapping Unparametrized Surfaces on the GPU by Morten S. Mikkelsen
// http://api.unrealengine.com/attachments/Engine/Rendering/LightingAndShadows/BumpMappingWithoutTangentSpace/mm_sfgrad_bump.pdf

// Evaluate the derivative of the height w.r.t. screen-space using forward
// differencing (listing 2)

vec2 dHdxy_fwd() {

  vec2 dSTdx = dFdx(vUv);
  vec2 dSTdy = dFdy(vUv);

  float Hll = bumpScale * texture2D(bumpMap, vUv).x;
  float dBx = bumpScale * texture2D(bumpMap, vUv + dSTdx).x - Hll;
  float dBy = bumpScale * texture2D(bumpMap, vUv + dSTdy).x - Hll;

  return vec2(dBx, dBy);
}

vec3 perturbNormalArb(vec3 surf_pos, vec3 surf_norm, vec2 dHdxy,
                      float faceDirection) {

  // Workaround for Adreno 3XX dFd*( vec3 ) bug. See #9988

  vec3 vSigmaX = vec3(dFdx(surf_pos.x), dFdx(surf_pos.y), dFdx(surf_pos.z));
  vec3 vSigmaY = vec3(dFdy(surf_pos.x), dFdy(surf_pos.y), dFdy(surf_pos.z));
  vec3 vN = surf_norm; // normalized

  vec3 R1 = cross(vSigmaY, vN);
  vec3 R2 = cross(vN, vSigmaX);

  float fDet = dot(vSigmaX, R1) * faceDirection;

  vec3 vGrad = sign(fDet) * (dHdxy.x * R1 + dHdxy.y * R2);
  return normalize(abs(fDet) * surf_norm - vGrad);
}

#endif

#ifdef USE_NORMALMAP

uniform sampler2D normalMap;
uniform vec2 normalScale;

#endif

#ifdef OBJECTSPACE_NORMALMAP

uniform mat3 normalMatrix;

#endif

#if !defined(USE_TANGENT) &&                                                   \
    (defined(TANGENTSPACE_NORMALMAP) || defined(USE_CLEARCOAT_NORMALMAP))

// Normal Mapping Without Precomputed Tangents
// http://www.thetenthplanet.de/archives/1180

vec3 perturbNormal2Arb(vec3 eye_pos, vec3 surf_norm, vec3 mapN,
                       float faceDirection) {

  // Workaround for Adreno 3XX dFd*( vec3 ) bug. See #9988

  vec3 q0 = vec3(dFdx(eye_pos.x), dFdx(eye_pos.y), dFdx(eye_pos.z));
  vec3 q1 = vec3(dFdy(eye_pos.x), dFdy(eye_pos.y), dFdy(eye_pos.z));
  vec2 st0 = dFdx(vUv.st);
  vec2 st1 = dFdy(vUv.st);

  vec3 N = surf_norm; // normalized

  vec3 q1perp = cross(q1, N);
  vec3 q0perp = cross(N, q0);

  vec3 T = q1perp * st0.x + q0perp * st1.x;
  vec3 B = q1perp * st0.y + q0perp * st1.y;

  float det = max(dot(T, T), dot(B, B));
  float scale = (det == 0.0) ? 0.0 : faceDirection * inversesqrt(det);

  return normalize(T * (mapN.x * scale) + B * (mapN.y * scale) + N * mapN.z);
}

#endif

#ifdef USE_CLEARCOATMAP

uniform sampler2D clearcoatMap;

#endif

#ifdef USE_CLEARCOAT_ROUGHNESSMAP

uniform sampler2D clearcoatRoughnessMap;

#endif

#ifdef USE_CLEARCOAT_NORMALMAP

uniform sampler2D clearcoatNormalMap;
uniform vec2 clearcoatNormalScale;

#endif

#ifdef USE_ROUGHNESSMAP

uniform sampler2D roughnessMap;

#endif

#ifdef USE_METALNESSMAP

uniform sampler2D metalnessMap;

#endif

#if defined(USE_LOGDEPTHBUF) && defined(USE_LOGDEPTHBUF_EXT)

uniform float logDepthBufFC;
varying float vFragDepth;
varying float vIsPerspective;

#endif

#if 0 > 0
      
      	varying vec3 vClipPosition;
      
      	uniform vec4 clippingPlanes[ 0 ];

#endif

void main() {

#if 0 > 0
      
      	vec4 plane;

#if 0 < 0
      
      		bool clipped = true;
      
      		
      
      		if ( clipped ) discard;

#endif

#endif

  vec4 diffuseColor = vec4(diffuse, opacity);
  ReflectedLight reflectedLight =
      ReflectedLight(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
  vec3 totalEmissiveRadiance = emissive;

#if defined(USE_LOGDEPTHBUF) && defined(USE_LOGDEPTHBUF_EXT)

  // Doing a strict comparison with == 1.0 can cause noise artifacts
  // on some platforms. See issue #17623.
  gl_FragDepthEXT = vIsPerspective == 0.0
                        ? gl_FragCoord.z
                        : log2(vFragDepth) * logDepthBufFC * 0.5;

#endif

#ifdef USE_MAP

  vec4 texelColor = texture2D(map, vUv);

  texelColor = mapTexelToLinear(texelColor);
  diffuseColor *= texelColor;

#endif

#if defined(USE_COLOR_ALPHA)

  diffuseColor *= vColor;

#elif defined(USE_COLOR)

  diffuseColor.rgb *= vColor;

#endif

#ifdef USE_ALPHAMAP

  diffuseColor.a *= texture2D(alphaMap, vUv).g;

#endif

#ifdef USE_ALPHATEST

  if (diffuseColor.a < alphaTest)
    discard;

#endif

  float roughnessFactor = roughness;

#ifdef USE_ROUGHNESSMAP

  vec4 texelRoughness = texture2D(roughnessMap, vUv);

  // reads channel G, compatible with a combined OcclusionRoughnessMetallic
  // (RGB) texture
  roughnessFactor *= texelRoughness.g;

#endif

  float metalnessFactor = metalness;

#ifdef USE_METALNESSMAP

  vec4 texelMetalness = texture2D(metalnessMap, vUv);

  // reads channel B, compatible with a combined OcclusionRoughnessMetallic
  // (RGB) texture
  metalnessFactor *= texelMetalness.b;

#endif

  float faceDirection = gl_FrontFacing ? 1.0 : -1.0;

#ifdef FLAT_SHADED

  // Workaround for Adreno GPUs not able to do dFdx( vViewPosition )

  vec3 fdx =
      vec3(dFdx(vViewPosition.x), dFdx(vViewPosition.y), dFdx(vViewPosition.z));
  vec3 fdy =
      vec3(dFdy(vViewPosition.x), dFdy(vViewPosition.y), dFdy(vViewPosition.z));
  vec3 normal = normalize(cross(fdx, fdy));

#else

  vec3 normal = normalize(vNormal);

#ifdef DOUBLE_SIDED

  normal = normal * faceDirection;

#endif

#ifdef USE_TANGENT

  vec3 tangent = normalize(vTangent);
  vec3 bitangent = normalize(vBitangent);

#ifdef DOUBLE_SIDED

  tangent = tangent * faceDirection;
  bitangent = bitangent * faceDirection;

#endif

#if defined(TANGENTSPACE_NORMALMAP) || defined(USE_CLEARCOAT_NORMALMAP)

  mat3 vTBN = mat3(tangent, bitangent, normal);

#endif

#endif

#endif

  // non perturbed normal for clearcoat among others

  vec3 geometryNormal = normal;

#ifdef OBJECTSPACE_NORMALMAP

  normal = texture2D(normalMap, vUv).xyz * 2.0 -
           1.0; // overrides both flatShading and attribute normals

#ifdef FLIP_SIDED

  normal = -normal;

#endif

#ifdef DOUBLE_SIDED

  normal = normal * faceDirection;

#endif

  normal = normalize(normalMatrix * normal);

#elif defined(TANGENTSPACE_NORMALMAP)

  vec3 mapN = texture2D(normalMap, vUv).xyz * 2.0 - 1.0;
  mapN.xy *= normalScale;

#ifdef FLIP_NORMAL_SCALE_Y
  mapN.y *= -1.0;
#endif

#ifdef USE_TANGENT

  normal = normalize(vTBN * mapN);

#else

  normal = perturbNormal2Arb(-vViewPosition, normal, mapN);

#endif

#elif defined(USE_BUMPMAP)

  normal = perturbNormalArb(-vViewPosition, normal, dHdxy_fwd());

#endif

#ifdef USE_CLEARCOAT

  vec3 clearcoatNormal = geometryNormal;

#endif

#ifdef USE_CLEARCOAT_NORMALMAP

  vec3 clearcoatMapN = texture2D(clearcoatNormalMap, vUv).xyz * 2.0 - 1.0;
  clearcoatMapN.xy *= clearcoatNormalScale;

#ifdef USE_TANGENT

  clearcoatNormal = normalize(vTBN * clearcoatMapN);

#else

  clearcoatNormal = perturbNormal2Arb(-vViewPosition, clearcoatNormal,
                                      clearcoatMapN, faceDirection);

#endif

#endif

#ifdef USE_EMISSIVEMAP

  vec4 emissiveColor = texture2D(emissiveMap, vUv);

  emissiveColor.rgb = emissiveMapTexelToLinear(emissiveColor).rgb;

  totalEmissiveRadiance *= emissiveColor.rgb;

#endif

  // accumulation
  PhysicalMaterial material;
  material.diffuseColor = diffuseColor.rgb * (1.0 - metalnessFactor);

  vec3 dxy = max(abs(dFdx(geometryNormal)), abs(dFdy(geometryNormal)));
  float geometryRoughness = max(max(dxy.x, dxy.y), dxy.z);

  material.roughness =
      max(roughnessFactor,
          0.0525); // 0.0525 corresponds to the base mip of a 256 cubemap.
  material.roughness += geometryRoughness;
  material.roughness = min(material.roughness, 1.0);

#ifdef IOR

#ifdef SPECULAR

  float specularIntensityFactor = specularIntensity;
  vec3 specularTintFactor = specularTint;

#ifdef USE_SPECULARINTENSITYMAP

  specularIntensityFactor *= texture2D(specularIntensityMap, vUv).a;

#endif

#ifdef USE_SPECULARTINTMAP

  specularTintFactor *=
      specularTintMapTexelToLinear(texture2D(specularTintMap, vUv)).rgb;

#endif

  material.specularF90 = mix(specularIntensityFactor, 1.0, metalnessFactor);

#else

  float specularIntensityFactor = 1.0;
  vec3 specularTintFactor = vec3(1.0);
  material.specularF90 = 1.0;

#endif

  material.specularColor =
      mix(min(pow2((ior - 1.0) / (ior + 1.0)) * specularTintFactor, vec3(1.0)) *
              specularIntensityFactor,
          diffuseColor.rgb, metalnessFactor);

#else

  material.specularColor = mix(vec3(0.04), diffuseColor.rgb, metalnessFactor);
  material.specularF90 = 1.0;

#endif

#ifdef USE_CLEARCOAT

  material.clearcoat = clearcoat;
  material.clearcoatRoughness = clearcoatRoughness;
  material.clearcoatF0 = vec3(0.04);
  material.clearcoatF90 = 1.0;

#ifdef USE_CLEARCOATMAP

  material.clearcoat *= texture2D(clearcoatMap, vUv).x;

#endif

#ifdef USE_CLEARCOAT_ROUGHNESSMAP

  material.clearcoatRoughness *= texture2D(clearcoatRoughnessMap, vUv).y;

#endif

  material.clearcoat = saturate(material.clearcoat); // Burley clearcoat model
  material.clearcoatRoughness = max(material.clearcoatRoughness, 0.0525);
  material.clearcoatRoughness += geometryRoughness;
  material.clearcoatRoughness = min(material.clearcoatRoughness, 1.0);

#endif

#ifdef USE_SHEEN

  material.sheenTint = sheenTint;
  material.sheenRoughness = clamp(sheenRoughness, 0.07, 1.0);

#endif

  /**
   * This is a template that can be used to light a material, it uses pluggable
   * RenderEquations (RE)for specific lighting scenarios.
   *
   * Instructions for use:
   * - Ensure that both RE_Direct, RE_IndirectDiffuse and RE_IndirectSpecular
   * are defined
   * - If you have defined an RE_IndirectSpecular, you need to also provide a
   * Material_LightProbeLOD. <---- ???
   * - Create a material parameter that is to be passed as the third parameter
   * to your lighting functions.
   *
   * TODO:
   * - Add area light support.
   * - Add sphere light support.
   * - Add diffuse light probe (irradiance cubemap) support.
   */

  GeometricContext geometry;

  geometry.position = -vViewPosition;
  geometry.normal = normal;
  geometry.viewDir =
      (isOrthographic) ? vec3(0, 0, 1) : normalize(vViewPosition);

#ifdef USE_CLEARCOAT

  geometry.clearcoatNormal = clearcoatNormal;

#endif

  IncidentLight directLight;

#if (0 > 0) && defined(RE_Direct)

  PointLight pointLight;
#if defined(USE_SHADOWMAP) && 0 > 0
  PointLightShadow pointLightShadow;
#endif

#endif

#if (1 > 0) && defined(RE_Direct)

  SpotLight spotLight;
#if defined(USE_SHADOWMAP) && 1 > 0
  SpotLightShadow spotLightShadow;
#endif

  spotLight = spotLights[0];

  getSpotLightInfo(spotLight, geometry, directLight);

#if defined(USE_SHADOWMAP) && (0 < 1)
  spotLightShadow = spotLightShadows[0];
  directLight.color *=
      all(bvec2(directLight.visible, receiveShadow))
          ? getShadow(spotShadowMap[0], spotLightShadow.shadowMapSize,
                      spotLightShadow.shadowBias, spotLightShadow.shadowRadius,
                      vSpotShadowCoord[0])
          : 1.0;
#endif

  RE_Direct(directLight, geometry, material, reflectedLight);

#endif

#if (0 > 0) && defined(RE_Direct)

  DirectionalLight directionalLight;
#if defined(USE_SHADOWMAP) && 0 > 0
  DirectionalLightShadow directionalLightShadow;
#endif

#endif

#if (0 > 0) && defined(RE_Direct_RectArea)

  RectAreaLight rectAreaLight;

#endif

#if defined(RE_IndirectDiffuse)

  vec3 iblIrradiance = vec3(0.0);

  vec3 irradiance = getAmbientLightIrradiance(ambientLightColor);

  irradiance += getLightProbeIrradiance(lightProbe, geometry.normal);

#if (0 > 0)

#endif

#endif

#if defined(RE_IndirectSpecular)

  vec3 radiance = vec3(0.0);
  vec3 clearcoatRadiance = vec3(0.0);

#endif

#if defined(RE_IndirectDiffuse)

#ifdef USE_LIGHTMAP

  vec4 lightMapTexel = texture2D(lightMap, vUv2);
  vec3 lightMapIrradiance =
      lightMapTexelToLinear(lightMapTexel).rgb * lightMapIntensity;

#ifndef PHYSICALLY_CORRECT_LIGHTS

  lightMapIrradiance *= PI;

#endif

  irradiance += lightMapIrradiance;

#endif

#if defined(USE_ENVMAP) && defined(STANDARD) && defined(ENVMAP_TYPE_CUBE_UV)

  iblIrradiance +=
      getLightProbeIndirectIrradiance(/*lightProbe,*/ geometry, maxMipLevel);

#endif

#endif

#if defined(USE_ENVMAP) && defined(RE_IndirectSpecular)

  radiance += getLightProbeIndirectRadiance(
      /*specularLightProbe,*/ geometry.viewDir, geometry.normal,
      material.roughness, maxMipLevel);

#ifdef USE_CLEARCOAT

  clearcoatRadiance += getLightProbeIndirectRadiance(
      /*specularLightProbe,*/ geometry.viewDir, geometry.clearcoatNormal,
      material.clearcoatRoughness, maxMipLevel);

#endif

#endif

#if defined(RE_IndirectDiffuse)

  RE_IndirectDiffuse(irradiance, geometry, material, reflectedLight);

#endif

#if defined(RE_IndirectSpecular)

  RE_IndirectSpecular(radiance, iblIrradiance, clearcoatRadiance, geometry,
                      material, reflectedLight);

#endif

  // modulation
#ifdef USE_AOMAP

  // reads channel R, compatible with a combined OcclusionRoughnessMetallic
  // (RGB) texture
  float ambientOcclusion =
      (texture2D(aoMap, vUv2).r - 1.0) * aoMapIntensity + 1.0;

  reflectedLight.indirectDiffuse *= ambientOcclusion;

#if defined(USE_ENVMAP) && defined(STANDARD)

  float dotNV = saturate(dot(geometry.normal, geometry.viewDir));

  reflectedLight.indirectSpecular *=
      computeSpecularOcclusion(dotNV, ambientOcclusion, material.roughness);

#endif

#endif

  vec3 totalDiffuse =
      reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
  vec3 totalSpecular =
      reflectedLight.directSpecular + reflectedLight.indirectSpecular;

#ifdef USE_TRANSMISSION

  float transmissionFactor = transmission;
  float thicknessFactor = thickness;

#ifdef USE_TRANSMISSIONMAP

  transmissionFactor *= texture2D(transmissionMap, vUv).r;

#endif

#ifdef USE_THICKNESSMAP

  thicknessFactor *= texture2D(thicknessMap, vUv).g;

#endif

  vec3 pos = vWorldPosition;
  vec3 v = normalize(cameraPosition - pos);
  vec3 n = inverseTransformDirection(normal, viewMatrix);

  vec3 transmission = getIBLVolumeRefraction(
      n, v, roughnessFactor, material.diffuseColor, material.specularColor,
      material.specularF90, pos, modelMatrix, viewMatrix, projectionMatrix, ior,
      thicknessFactor, attenuationTint, attenuationDistance);

  totalDiffuse = mix(totalDiffuse, transmission, transmissionFactor);
#endif

  vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;

#ifdef USE_CLEARCOAT

  float dotNVcc = saturate(dot(geometry.clearcoatNormal, geometry.viewDir));

  vec3 Fcc = F_Schlick(material.clearcoatF0, material.clearcoatF90, dotNVcc);

  outgoingLight =
      outgoingLight * (1.0 - clearcoat * Fcc) + clearcoatSpecular * clearcoat;

#endif

#ifdef OPAQUE
  diffuseColor.a = 1.0;
#endif

// https://github.com/mrdoob/three.js/pull/22425
#ifdef USE_TRANSMISSION
  diffuseColor.a *= transmissionAlpha + 0.1;
#endif

  gl_FragColor = vec4(outgoingLight, diffuseColor.a);

#if defined(TONE_MAPPING)

  gl_FragColor.rgb = toneMapping(gl_FragColor.rgb);

#endif

  gl_FragColor = linearToOutputTexel(gl_FragColor);

#ifdef USE_FOG

#ifdef FOG_EXP2

  float fogFactor = 1.0 - exp(-fogDensity * fogDensity * vFogDepth * vFogDepth);

#else

  float fogFactor = smoothstep(fogNear, fogFar, vFogDepth);

#endif

  gl_FragColor.rgb = mix(gl_FragColor.rgb, fogColor, fogFactor);

#endif

#ifdef PREMULTIPLIED_ALPHA

  // Get get normal blending with premultipled, use with CustomBlending,
  // OneFactor, OneMinusSrcAlphaFactor, AddEquation.
  gl_FragColor.rgb *= gl_FragColor.a;

#endif

#ifdef DITHERING

  gl_FragColor.rgb = dithering(gl_FragColor.rgb);

#endif
}