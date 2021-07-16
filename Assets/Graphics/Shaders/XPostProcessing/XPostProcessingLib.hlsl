#ifndef __XPOSTPROCESSING_LIB_INCLUDE__
#define __XPOSTPROCESSING_LIB_INCLUDE__

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
SAMPLER(sampler_SrcTex);

half4 SampleSrcTex(float2 uv)
{
    return SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, uv);
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

#endif
