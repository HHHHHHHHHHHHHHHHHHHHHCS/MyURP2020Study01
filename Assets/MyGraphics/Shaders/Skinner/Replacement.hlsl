#ifndef __REPLACEMENT_INCLUDE__
#define __REPLACEMENT_INCLUDE__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct a2v
{
    float4 vertex:POSITION;
    float2 uv :TEXCOORD0;
    #ifdef SKINNER_NORMAL
    half3 normal:NORMAL;
    #endif
    #ifdef SKINNER_TANGENT
    half4 tangent:TANGENT;
    #endif
};

struct v2f
{
    float4 position:SV_POSITION;
    #ifdef SKINNER_POSITION
    float3 wpos:TEXCOORD0;
    #endif
    #ifdef SKINNER_NORMAL
    half3 normal:NORMAL;
    #endif
    #ifdef SKINNER_TANGENT
    half4 tangent:TANGENT;
    #endif
    #if defined(SHADER_API_METAL)||defined(SHADER_API_VULKAN)
        float psize:PSIZE;
    #endif
};

#ifdef SKINNER_MRT
struct FragmentOutput
{
    float4 position:SV_Target0;
    half4 normal:SV_Target1;
    half4 tangent:SV_Target2;
};
#endif


v2f vert(a2v v)
{
    v2f o;
    // POSITION <= UV on the attribute buffer
    o.position = float4(v.uv.x * 2 - 1, 0, 0, 1);
    #if defined(SKINNER_POSITION)
    // TEXCOORD <= World position
    o.wpos = TransformObjectToWorld(v.vertex.xyz);
    #endif
    #if defined(SKINNER_NORMAL)
    // NORMAL <= World normal
    o.normal = TransformObjectToWorldNormal(v.normal);
    #endif
    #if defined(SKINNER_TANGENT)
    // TANGENT <= World tangent
    o.tangent = half4(TransformObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #endif
    #if defined(SHADER_API_METAL) || defined(SHADER_API_VULKAN)
    // Metal/Vulkan: Point size should be explicitly given.
    o.psize = 1;
    #endif
    return o;
}

#if defined(SKINNER_MRT)
FragmentOutput frag(v2f i)
{
    FragmentOutput o;
    o.position = float4(i.wpos, 0);
    o.normal = half4(i.normal, 0);
    o.tangent = i.tangent;
    return o;
}
#else
half4 frag(v2f i) : SV_Target
{
#if defined(SKINNER_POSITION)
    return float4(i.wpos, 0);
#elif defined(SKINNER_NORMAL)
    return half4(i.normal, 0);
#elif defined(SKINNER_TANGENT)
    return i.tangent;
#endif
}

#endif

#endif
