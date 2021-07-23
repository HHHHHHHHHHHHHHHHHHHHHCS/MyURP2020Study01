#ifndef __3_SHADING_COMMON_FINAL__
#define __3_SHADING_COMMON_FINAL__

#include "3_ParameterCommon_Final.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


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
    float3 normalDir : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
};

v2f vert(a2v v)
{
    v2f o;
    o.worldPos = TransformObjectToWorld(v.vertex.xyz);
    o.vertex = TransformWorldToHClip(o.worldPos);
    o.normalDir = TransformObjectToWorldNormal(v.normal);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    return o;
}

half4 frag(v2f IN):SV_Target
{
    half3 normalDir = normalize(IN.normalDir);
    half3 lightDir = normalize(_MainLightPosition.xyz);
    half3 viewDir = normalize(GetWorldSpaceViewDir(IN.worldPos));
    half3 halfDir = normalize(lightDir + viewDir);

    half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;

    #ifdef IS_ALPHATEST
        clip(albedo.a - _Cutoff);
    #endif


    //Ambient Lighting
    half3 ambient = max(SampleSH(half3(0.0, 1.0, 0.0)), SampleSH(half3(0.0, -1.0, 0.0)));

    //Diffuse Lighting
    half nl = dot(normalDir, lightDir) * 0.5 + 0.5;
    half2 diffGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap, float2(nl, 0.5)).rg;
    half3 diffAlbedo = lerp(
        albedo.rgb,
        SAMPLE_TEXTURE2D(_ShadowColor1stTex, sampler_ShadowColor1stTex, IN.uv).rgb * _ShadowColor1st,
        diffGradient.x);
    diffAlbedo = lerp(
        diffAlbedo,
        SAMPLE_TEXTURE2D(_ShadowColor2ndTex, sampler_ShadowColor2ndTex, IN.uv).rgb * _ShadowColor2nd,
        diffGradient.y);
    half3 diff = diffAlbedo;

    //Specular Lighting
    half nh = dot(normalDir, halfDir);
    half specGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap,
                                         float2(pow(max(nh, 1e-5), _SpecularPower), 0.5)).b;
    half3 spec = specGradient * albedo.rgb * _SpecularColor;

    //Rim Lighting
    half nv = dot(normalDir, viewDir);
    half rimLightGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap,
                                             float2(pow(max(1.0 - clamp(nv, 0.0, 1.0), 1e-5), _RimLightPower
                                             ), 0.5)).a;
    half rimLightMask = SAMPLE_TEXTURE2D(_RimLightMask, sampler_RimLightMask, IN.uv).r;
    half3 rimLight = (rimLightGradient * rimLightMask) * _RimLightColor * diff;

    half3 col = ambient * albedo.rgb + (diff + spec) * _MainLightColor.rgb + rimLight;
    
    #ifdef IS_TRANSPARENT
        half alpha = albedo.a;
    #else
        half alpha = 1.0;
    #endif

    return half4(col, alpha);
}

#endif
