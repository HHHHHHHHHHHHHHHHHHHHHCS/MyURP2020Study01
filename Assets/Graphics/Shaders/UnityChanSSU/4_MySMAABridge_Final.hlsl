#ifndef __4_MY_SMAA_BRIDGE_FINAL__
#define __4_MY_SMAA_BRIDGE_FINAL__

#include "4_PostProcessCommon_Final.hlsl"

#define SMAA_HLSL_4_1

#define SMAA_RT_METRICS _SrcTex_TexelSize
#define SMAA_AREATEX_SELECT(s) s.rg
#define SMAA_SEARCHTEX_SELECT(s) s.a
#define LinearSampler sampler_Linear_Clamp
#define PointSampler sampler_Point_Clamp
#if UNITY_COLORSPACE_GAMMA
    #define GAMMA_FOR_EDGE_DETECTION (1)
#else
#define GAMMA_FOR_EDGE_DETECTION (1/2.2)
#endif

TEXTURE2D(_AreaTex);
TEXTURE2D(_SearchTex);
TEXTURE2D(_BlendTex);


#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/SubpixelMorphologicalAntialiasing.hlsl"


// ----------------------------------------------------------------------------------------
// Edge Detection
struct VaryingsEdge
{
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
    float4 offsets[3] : TEXCOORD1;
};

VaryingsEdge VertEdge(a2v IN)
{
    VaryingsEdge o;
    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.texcoord = GetFullScreenTriangleTexCoord(IN.vertexID);

    o.offsets[0] = mad(SMAA_RT_METRICS.xyxy, float4(-1, 0, 0, -1), o.texcoord.xyxy);
    o.offsets[1] = mad(SMAA_RT_METRICS.xyxy, float4(1, 0, 0, 1), o.texcoord.xyxy);
    o.offsets[2] = mad(SMAA_RT_METRICS.xyxy, float4(-2, 0, 0, -2), o.texcoord.xyxy);

    return o;
}

float4 FragEdge(VaryingsEdge i) : SV_Target
{
    return float4(SMAAColorEdgeDetectionPS(i.texcoord, i.offsets, _SrcTex), 0.0, 0.0);
}


// ----------------------------------------------------------------------------------------
// Blend Weights Calculation

struct VaryingsBlend
{
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
    float2 pixcoord : TEXCOORD1;
    float4 offsets[3] : TEXCOORD2;
};


VaryingsBlend VertBlend(a2v IN)
{
    VaryingsBlend o;

    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.texcoord = GetFullScreenTriangleTexCoord(IN.vertexID);

    o.pixcoord = o.texcoord * SMAA_RT_METRICS.zw;

    // We will use these offsets for the searches later on (see @PSEUDO_GATHER4):
    o.offsets[0] = mad(SMAA_RT_METRICS.xyxy, float4(-0.250, -0.125, 1.250, -0.125), o.texcoord.xyxy);
    o.offsets[1] = mad(SMAA_RT_METRICS.xyxy, float4(-0.125, -0.250, -0.125, 1.250), o.texcoord.xyxy);

    // And these for the searches, they indicate the ends of the loops:
    o.offsets[2] = mad(SMAA_RT_METRICS.xxyy, float4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS),
                       float4(o.offsets[0].xz, o.offsets[1].yw));

    return o;
}

float4 FragBlend(VaryingsBlend i) : SV_Target
{
    return SMAABlendingWeightCalculationPS(i.texcoord, i.pixcoord, i.offsets, _SrcTex, _AreaTex, _SearchTex, 0);
}

// ----------------------------------------------------------------------------------------
// Neighborhood Blending

struct VaryingsNeighbor
{
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
    float4 offset : TEXCOORD1;
};

VaryingsNeighbor VertNeighbor(a2v IN)
{
    VaryingsNeighbor o;
    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.texcoord = GetFullScreenTriangleTexCoord(IN.vertexID);
    
    o.offset = mad(SMAA_RT_METRICS.xyxy, float4(1.0, 0.0, 0.0, 1.0), o.texcoord.xyxy);

    return o;
}

float4 FragNeighbor(VaryingsNeighbor i) : SV_Target
{
    return SMAANeighborhoodBlendingPS(i.texcoord, i.offset, _SrcTex, _BlendTex);
}

#endif
