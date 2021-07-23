#ifndef __3_PARAMETER_COMMON_FINAL__
#define __3_PARAMETER_COMMON_FINAL__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;

#ifdef IS_ALPHATEST
half _Cutoff;
#endif

half4 _Color;

half3 _ShadowColor1st;
half3 _ShadowColor2nd;

half3 _SpecularColor;
half _SpecularPower;
half _SpecularThreshold;

half3 _RimLightColor;
half _RimLightPower;

float _OutlineWidth;
half3 _OutlineColor;

CBUFFER_END
		
TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D(_GradientMap);
SAMPLER(sampler_GradientMap);
TEXTURE2D(_ShadowColor1stTex);
SAMPLER(sampler_ShadowColor1stTex);
TEXTURE2D(_ShadowColor2ndTex);
SAMPLER(sampler_ShadowColor2ndTex);
TEXTURE2D(_RimLightMask);
SAMPLER(sampler_RimLightMask);

#endif