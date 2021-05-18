#ifndef __3_OUTLINE_COMMON_FINAL__
#define __3_OUTLINE_COMMON_FINAL__

#include "3_ParameterCommon_Final.hlsl"


struct a2v
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
};

v2f vert(a2v v)
{
    v2f o;

    //UNITY_MATRIX_MV == mul(UNITY_MATRIX_V, UNITY_MATRIX_M)
    float3 viewPos = mul(UNITY_MATRIX_MV, v.vertex).xyz;
    float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
    viewNormal.z = -0.5;
    viewPos += normalize(viewNormal) * _OutlineWidth * 0.002;

    o.vertex = TransformWViewToHClip(viewPos);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);

    return o;
}

half4 frag(v2f IN):SV_Target
{
    half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;

    #ifdef IS_ALPHATEST
    clip(albedo.a - _Cutoff);
    #endif
    
    half3 col = albedo.rgb * _OutlineColor;

    #ifdef IS_TRANSPARENT
    half alpha = albedo.a;
    #else
    half alpha = 1.0;
    #endif

    return half4(col, alpha);
}

#endif