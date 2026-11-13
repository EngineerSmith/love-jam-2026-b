
#ifdef VERTEX

layout(location = 0) in vec3 VertexPosition;
layout(location = 1) in vec2 VertexTexCoord;
layout(location = 2) in vec4 VertexColor;
layout(location = 3) in vec3 VertexNormal;

uniform mat4 u_ModelMatrix;
uniform mat4 u_ViewMatrix;
uniform mat4 u_ProjectionMatrix;

out highp vec2 v_TexCoord;
out highp vec3 v_Normal;
out mediump vec4 v_Color;
out highp vec3 v_ViewPosition;
out highp vec3 v_WorldPosition;

void vertexmain() {
  vec4 worldPosition = u_ModelMatrix * vec4(VertexPosition, 1.0);
  vec4 viewPosition = u_ViewMatrix * worldPosition;
  gl_Position = u_ProjectionMatrix * viewPosition; // screenPosition

  v_TexCoord = VertexTexCoord;
  v_Normal = normalize(mat3(u_ModelMatrix) * VertexNormal);
  v_Color = VertexColor;
  v_ViewPosition = viewPosition.xyz;
  v_WorldPosition = worldPosition.xyz;
}
#endif

#ifdef PIXEL

layout(location = 0) out vec4 love_PixelColor;

// Material
uniform vec3 u_AmbientColor;
uniform vec3 u_DiffuseColor;
uniform vec3 u_SpecularColor;
uniform float u_SpecularExponent;
uniform Image u_DiffuseTexture;

// Lighting
uniform vec3 u_LightDirection;
uniform vec3 u_LightDiffuseColor;
uniform vec3 u_LightAmbientColor;

// Shadows
struct ShadowSpot {
  vec3 position;
  vec2 radius;
  float intensity;
  float softness;
  float rotation;
};

const int MAX_SHADOW_SPOTS = 32;
uniform ShadowSpot u_ShadowSpots[MAX_SHADOW_SPOTS];
uniform int u_ShadowSpotCount;

in highp vec2 v_TexCoord;
in highp vec3 v_Normal;
in mediump vec4 v_Color;
in highp vec3 v_ViewPosition;
in highp vec3 v_WorldPosition;

void pixelmain() {
  vec4 texColor = Texel(u_DiffuseTexture, v_TexCoord);
  if (texColor.a < 1e-4) discard;

  vec4 baseColor = vec4(u_DiffuseColor, 1.0) * texColor * v_Color;

  vec3 N = normalize(v_Normal);
  vec3 L = normalize(u_LightDirection);
  vec3 V = normalize(-v_ViewPosition);

  float totalShadowMultiplier = 1.0;
  int activeCount = clamp(u_ShadowSpotCount, 0, MAX_SHADOW_SPOTS);

  for (int i = 0; i < MAX_SHADOW_SPOTS; i++) {
    if (i >= activeCount) break; // compiler will unwrap the loop by using constants
    ShadowSpot spot = u_ShadowSpots[i];

    vec3 toPixel = v_WorldPosition - spot.position;
    vec2 p = toPixel.xy;

    float c = cos(spot.rotation);
    float s = sin(spot.rotation);
    float dx =  p.x * c + p.y * s;
    float dy = -p.x * s + p.y * c;

    vec2 ovalCoord = vec2(dx / spot.radius.x, dy / spot.radius.y);
    float ovalDist = length(ovalCoord);

    float avgRadius = (spot.radius.x + spot.radius.y) * 0.5;
    float adjustedSoftness = spot.softness / max(avgRadius, 1e-3);

    float innerEdge = max(0.0, 1.0 - adjustedSoftness);
    float shadowFactor = 1.0 - smoothstep(innerEdge, 1.0, ovalDist);
    float shadowMultiplier = mix(1.0, 1.0 - spot.intensity, shadowFactor);

    totalShadowMultiplier *= shadowMultiplier;
  }

  vec3 ambient = u_AmbientColor * u_LightAmbientColor * baseColor.rgb;

  float diff = max(dot(N, L), 0.0);
  vec3 diffuse = diff * u_LightDiffuseColor * baseColor.rgb;

  // vec3 specular = vec3(0.0);
  // if (diff > 0.0 && u_SpecularExponent > 0.0) {
  //   vec3 H = normalize(L + V);
  //   float spec = pow(max(dot(N, H), 0.0), u_SpecularExponent);
  //   specular = spec * u_SpecularColor * u_LightDiffuseColor;
  // }

  vec3 finalRGB = ambient + (diffuse /*+ specular*/) * totalShadowMultiplier;
  love_PixelColor = vec4(finalRGB, baseColor.a);
}

#endif