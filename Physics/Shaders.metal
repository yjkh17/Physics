//  Shaders.metal – solid-colour pass (no textures)
#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
using namespace metal;

struct VIn  { float3 pos [[attribute(0)]]; };
struct VOut { float4 pos [[position]];    };

vertex VOut vertexShader(VIn vin [[stage_in]],
                         constant Uniforms& u [[buffer(2)]])
{
    VOut out;
    out.pos = u.projectionMatrix * u.modelViewMatrix * float4(vin.pos, 1);
    return out;
}

fragment float4 fragmentShader(constant Uniforms& u [[buffer(2)]])
{
    return u.color;
}
