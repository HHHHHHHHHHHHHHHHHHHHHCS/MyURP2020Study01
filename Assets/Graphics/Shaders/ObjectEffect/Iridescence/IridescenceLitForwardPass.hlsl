#ifndef  __IRIDESCENCE_LIT_FORWARD_PASS__
#define __IRIDESCENCE_LIT_FORWARD_PASS__

#include "IridescenceLighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 texcoord : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
};

#endif
