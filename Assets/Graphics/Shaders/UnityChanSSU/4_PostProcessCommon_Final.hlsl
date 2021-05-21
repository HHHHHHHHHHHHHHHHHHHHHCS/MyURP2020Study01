#ifndef __4_POST_PROCESS_COMMON_FINAL__
#define __4_POST_PROCESS_COMMON_FINAL__

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

struct a2v
{
    uint vertexID :SV_VertexID;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vert(a2v IN)
{
    v2f o;
    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
    return o;
}

#endif
