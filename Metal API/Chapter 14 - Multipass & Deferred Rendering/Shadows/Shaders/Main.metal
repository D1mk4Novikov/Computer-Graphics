#include <metal_stdlib>
using namespace metal;
#import "../Utility/Common.h"

struct VertexIn {
  float4 position [[attribute(0)]];
  float3 normal [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 worldPosition;
  float3 worldNormal;
  float4 shadowPosition;
};

vertex VertexOut vertex_main(const VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]])
{
  VertexOut out;
  matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
  out.position = mvp * vertexIn.position;
  out.worldPosition = (uniforms.modelMatrix * vertexIn.position).xyz;
  out.worldNormal = uniforms.normalMatrix * vertexIn.normal, 0;
  out.shadowPosition = uniforms.shadowMatrix * uniforms.modelMatrix * vertexIn.position;
  return out;
}

float3 diffuseLighting(float3 normal,
                       float3 position,
                       constant FragmentUniforms &fragmentUniforms,
                       constant Light *lights,
                       float3 baseColor) {
  float3 diffuseColor = 0;
  float3 normalDirection = normalize(normal);
  for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
    Light light = lights[i];
    if (light.type == Sunlight) {
      float3 lightDirection = normalize(light.position);
      float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
      diffuseColor += light.color * light.intensity * baseColor * diffuseIntensity;
    } else if (light.type == Pointlight) {
      float d = distance(light.position, position);
      float3 lightDirection = normalize(light.position - position);
      float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
      float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
      float3 color = light.color * baseColor * diffuseIntensity;
      color *= attenuation;
      diffuseColor += color;
    } else if (light.type == Spotlight) {
      float d = distance(light.position, position);
      float3 lightDirection = normalize(light.position - position);
      float3 coneDirection = normalize(-light.coneDirection);
      float spotResult = (dot(lightDirection, coneDirection));
      if (spotResult > cos(light.coneAngle)) {
        float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
        attenuation *= pow(spotResult, light.coneAttenuation);
        float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
        float3 color = light.color * baseColor * diffuseIntensity;
        color *= attenuation;
        diffuseColor += color;
      }
    }
  }
  return diffuseColor;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant FragmentUniforms &fragmentUniforms [[buffer(3)]],
                              constant Light *lights [[buffer(2)]],
                              constant Material &material [[buffer(1)]],
                              depth2d<float> shadowTexture [[texture(0)]])
{
  float3 baseColor = material.baseColor;
  float3 diffuseColor = diffuseLighting(in.worldNormal, in.worldPosition, fragmentUniforms, lights, baseColor);
  
  float2 xy = in.shadowPosition.xy;
  xy = xy * 0.5 + 0.5;
  xy.y = 1 - xy.y;
  
  constexpr sampler s(coord::normalized, filter::linear,
                      address::clamp_to_edge, compare_func:: less);
  float shadow_sample = shadowTexture.sample(s, xy);
  float current_sample = in.shadowPosition.z / in.shadowPosition.w;
  
  if (current_sample > shadow_sample ) {
    diffuseColor *= 0.5;
  }
  return float4(diffuseColor, 1);
}
