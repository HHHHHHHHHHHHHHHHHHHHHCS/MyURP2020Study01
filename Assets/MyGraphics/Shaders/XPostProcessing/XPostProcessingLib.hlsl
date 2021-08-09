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

TEXTURE2D(_NoiseTex);
SAMPLER(sampler_NoiseTex);


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

//sample
//---------------
inline half4 SampleSrcTex(float2 uv)
{
    return SAMPLE_TEXTURE2D(_SrcTex, sampler_Linear_Clamp, uv);
}

inline half4 SampleNoiseTex(float2 uv)
{
    return SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uv);
}

//random
//-----------

inline float RandomNoise(float time, float2 seed, float speed)
{
    return frac(sin(dot(seed * floor(time * speed), float2(17.13, 3.71))) * 43758.5453123);
}

inline float RandomNoise(float time, float seed, float speed)
{
    return RandomNoise(time, float2(seed, 1.0), speed);
}

inline float RandomNoise(float time, float2 seed)
{
    return frac(sin(dot(seed * floor(time * 30.0), float2(127.1, 311.7))) * 43758.5453123);
}

inline float RandomNoise(float time, float seed)
{
    return RandomNoise(time, float2(seed, 1.0));
}

inline float RandomNoise(float2 seed)
{
    return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}

//func
//---------

inline float4 Pow4(float4 v, float p)
{
    return float4(pow(v.x, p), pow(v.y, p), pow(v.z, p), v.w);
}

//类似于分段取整
inline float Trunc(float x, float num_levels)
{
    return floor(x * num_levels) / num_levels;
}


#endif
