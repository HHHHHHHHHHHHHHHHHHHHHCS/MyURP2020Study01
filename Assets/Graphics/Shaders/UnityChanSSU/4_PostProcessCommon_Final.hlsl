#ifndef __4_POST_PROCESS_COMMON_FINAL__
#define __4_POST_PROCESS_COMMON_FINAL__

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#define EPSILON         1.0e-4

struct a2v
{
    uint vertexID :SV_VertexID;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
};

TEXTURE2D(_SrcTex);
SAMPLER(sampler_SrcTex);
float4 _SrcTex_TexelSize;

v2f VertDefault(a2v IN)
{
    v2f o;
    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
    return o;
}

#endif
