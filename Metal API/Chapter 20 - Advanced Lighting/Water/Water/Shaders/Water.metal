#include <metal_stdlib>
using namespace metal;

#import "Common.h"

struct VertexIn {
  float4 position [[ attribute(0) ]];
  float2 uv [[ attribute(2) ]];
};

struct VertexOut {
  float4 position [[ position ]];
  float2 uv;
  float3 worldPosition;
  float3 toCamera;
};

vertex VertexOut vertex_water(const VertexIn vertex_in [[ stage_in ]],
                              constant Uniforms &uniforms
                              [[ buffer(BufferIndexUniforms) ]]) {
  VertexOut vertex_out;
  float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix
  * uniforms.modelMatrix;
  vertex_out.position = mvp * vertex_in.position;
  vertex_out.uv = vertex_in.uv;
  vertex_out.worldPosition =
  (uniforms.modelMatrix * vertex_in.position).xyz;
  vertex_out.toCamera = uniforms.cameraPosition - vertex_out.worldPosition;
  return vertex_out;
}

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]],
                               texture2d<float> reflectionTexture [[ texture(0) ]],
                               texture2d<float> refractionTexture [[ texture(1) ]],
                               texture2d<float> normalTexture [[ texture(2) ]],
                               constant float& timer [[ buffer(3) ]],
                               depth2d<float> depthMap [[ texture(4 )]]) {
  constexpr sampler s(filter::linear, address::repeat);
  float width = float(reflectionTexture.get_width() * 2.0);
  float height = float(reflectionTexture.get_height() * 2.0);
  float x = vertex_in.position.x / width;
  float y = vertex_in.position.y / height;
  
  float2 reflectionCoords = float2(x, 1 - y);
  float2 refractionCoords = float2(x, y);
  
  float proj33 = far / (far - near); // these are from MathLibrary
  float proj43 = proj33 * -near;     // projection matrix at 3,3 and 4,3
  float depth = depthMap.sample(s, refractionCoords);
  float floorDistance = proj43 / (depth - proj33);
  depth = vertex_in.position.z;
  float waterDistance = proj43 / (depth - proj33);
  depth = floorDistance - waterDistance;
  
  float2 uv = vertex_in.uv * 2.0;
  float waveStrength = 0.1;
  float2 rippleX = float2(uv.x + timer, uv.y);
  float2 rippleY = float2(-uv.x, uv.y) + timer;
  float2 ripple = ((normalTexture.sample(s, rippleX).rg * 2.0 - 1.0) +
                   (normalTexture.sample(s, rippleY).rg * 2.0 - 1.0))
  * waveStrength;
  reflectionCoords += ripple;
  refractionCoords += ripple;
  reflectionCoords = clamp(reflectionCoords, 0.001, 0.999);
  refractionCoords = clamp(refractionCoords, 0.001, 0.999);

  float3 viewVector = normalize(vertex_in.toCamera);
  float mixRatio = dot(viewVector, float3(0.0, 1.0, 0.0));
  float4 color = mix(reflectionTexture.sample(s, reflectionCoords),
                     refractionTexture.sample(s, refractionCoords),
                     mixRatio);
  color = mix(color, float4(0.0, 0.3, 0.5, 1.0), 0.3);
  color.a = clamp(depth * 0.75, 0.0, 1.0);
  return color;
  
}

