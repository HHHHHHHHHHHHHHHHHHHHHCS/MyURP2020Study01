Shader "MyRP/UnityChanSSU/4_MyBloom_Final"
{
	//    Properties
	//    {
	//    }

	HLSLINCLUDE
	#include "4_PostProcessCommon_Final.hlsl"

	TEXTURE2D(_BloomTex);
	//我们这里省略了 _AutoExposureTex

	float _SampleScale;
	float4 _ColorIntensity;
	float4 _Threshold; //x:threshold value (linear), y: threshold - knee , z: knee *2 , w: 0.25/knee
	float4 _Params; // x: clamp , yzw:unused


	// ----------------------------------------------------------------------------------------
	// Prefilter
	//
	// Quadratic color thresholding
	// curve = (threshold - knee, knee * 2, 0.25 / knee)
	//
	half4 QuadraticThreshold(half4 color, half threshold, half3 curve)
	{
		half br = Max3(color.r, color.g, color.b);

		half rq = clamp(br - curve.x, 0.0, curve.y);
		rq = curve.z * rq * rq;

		color *= max(rq, br - threshold) / max(br,EPSILON);

		return color;
	}
	
	half4 Prefilter(half4 color, float2 uv)
	{
		//half autoExposure  这里省略了这个
		color = min(_Params.xxxx, color);
		color = QuadraticThreshold(color, _Threshold.x, _Threshold.yzw);
		return color;
	}

	half4 FragPrefilter13(v2f IN):SV_Target
	{
		//我们不支持XR
		_SrcTex_TexelSize = UnityStereoAdjustedTexelSize(_SrcTex_TexelSize);

		half4 color = DownsampleBox13Tap(TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv, _SrcTex_TexelSize.xy);
		return Prefilter(SafeHDR(color), IN.uv);
	}

	half4 FragPrefilter4(v2f IN) : SV_Target
	{
		half4 color = DownsampleBox4Tap(TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv, _SrcTex_TexelSize.xy);
		return Prefilter(SafeHDR(color), IN.uv);
	}

	// ----------------------------------------------------------------------------------------
	// Downsample

	half4 FragDownsample13(v2f IN) : SV_Target
	{
		half4 color = DownsampleBox13Tap(
			TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv,
			_SrcTex_TexelSize.xy);
		return color;
	}

	half4 FragDownsample4(v2f IN) : SV_Target
	{
		half4 color = DownsampleBox4Tap(
			TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv,
			_SrcTex_TexelSize.xy);
		return color;
	}

	// ----------------------------------------------------------------------------------------
	// Upsample & combine

	half4 Combine(half4 bloom, float2 uv)
	{
		half4 color = SAMPLE_TEXTURE2D(_BloomTex, sampler_Linear_Clamp, uv);
		return bloom + color;
	}

	half4 FragUpsampleTent(v2f IN): SV_Target
	{
		half4 bloom = UpsampleTent(TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv, _SrcTex_TexelSize.xy, _SampleScale);
		return Combine(bloom, IN.uv);
	}

	half4 FragUpsampleBox(v2f IN) : SV_Target
	{
		half4 bloom = UpsampleBox(TEXTURE2D_ARGS(_SrcTex, sampler_SrcTex), IN.uv, _SrcTex_TexelSize.xy, _SampleScale);
		return Combine(bloom, IN.uv);
	}
	ENDHLSL

	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		// 0: Prefilter 13 taps
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragPrefilter13
			ENDHLSL
		}

		// 1: Prefilter 4 taps
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragPrefilter4
			ENDHLSL
		}

		// 2: Downsample 13 taps
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragDownsample13
			ENDHLSL
		}

		// 3: Downsample 4 taps
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragDownsample4
			ENDHLSL
		}

		// 4: Upsample tent filter
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragUpsampleTent
			ENDHLSL
		}

		// 5: Upsample box filter
		Pass
		{
			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment FragUpsampleBox
			ENDHLSL
		}
	}
}