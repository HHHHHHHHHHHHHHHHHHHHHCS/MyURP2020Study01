Shader "MyRP/XPostProcessing/Vignette/RapidVignette"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"

	half _VignetteIntensity;
	half2 _VignetteCenter;

	half4 CalcColor(v2f IN, half3 col)
	{
		float2 center = IN.uv - _VignetteCenter;
		float vignetteIntensity = saturate( dot(center, center) * _VignetteIntensity);

		return half4(col, vignetteIntensity);
	}
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Blend SrcAlpha OneMinusSrcAlpha , Zero One

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 DoEffect(v2f IN)
			{
				return CalcColor(IN, 0);
			}
			ENDHLSL
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "../XPostProcessingLib.hlsl"

			half3 _VignetteColor;

			half4 DoEffect(v2f IN)
			{
				return CalcColor(IN, _VignetteColor);
			}
			ENDHLSL
		}
	}
}