//
//  ShaderTypes.h
//  Physics
//
//  Created by Yousef Jawdat on 15/05/2025.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    vector_float4   color;
} Uniforms;

#endif /* ShaderTypes_h */
