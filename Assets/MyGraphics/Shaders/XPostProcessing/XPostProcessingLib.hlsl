#ifndef __XPOSTPROCESSING_LIB_INCLUDE__
#define __XPOSTPROCESSING_LIB_INCLUDE__

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct a2v
{
    uint vertexID : SV_VertexID;
};

struct v2f
{
    float4 pos: SV_POSITION;
    float2 uv: TEXCOORD0;
};

TEXTURE2D(_SrcTex);
// SAMPLER(sampler_Point_Clamp);
SAMPLER(sampler_Linear_Clamp);

inline half4 SampleSrcTex(float2 uv)
{
    return SAMPLE_TEXTURE2D(_SrcTex, sampler_Linear_Clamp, uv);
}

half4 DoEffect(v2f IN);

v2f vert(a2v v)
{
    v2f o;
    o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
    o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
    return o;
}

half4 frag(v2f IN):SV_Target
{
    return DoEffect(IN);
}

//Common Function
//---------------------------

float RandomNoise(float time, float2 seed)
{
    return frac(sin(dot(seed * floor(time * 30.0), float2(127.1, 311.7))) * 43758.5453123);
}

float RandomNoise(float time, float seed)
{
    return RandomNoise(time, float2(seed, 1.0));
}

#endif
