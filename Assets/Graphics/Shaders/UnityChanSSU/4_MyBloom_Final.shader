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

	half4 SafeHDR(half4 c)
	{
		return min(c, HALF_MAX);
	}

	#if defined(UNITY_SINGLE_PASS_STEREO)
	float4 UnityStereoAdjustedTexelSize(float4 texelSize) // Should take in _MainTex_TexelSize
	{
		texelSize.x = texelSize.x * 2.0; // texelSize.x = 1/w. For a double-wide texture, the true resolution is given by 2/w. 
		texelSize.z = texelSize.z * 0.5; // texelSize.z = w. For a double-wide texture, the true size of the eye texture is given by w/2. 
		return texelSize;
	}
	#else

	float4 UnityStereoAdjustedTexelSize(float4 texelSize)
	{
		return texelSize;
	}
	#endif

	// Better, temporally stable box filtering
	// [Jimenez14] http://goo.gl/eomGso
	// . . . . . . .
	// . A . B . C .
	// . . D . E . .
	// . F . G . H .
	// . . I . J . .
	// . K . L . M .
	// . . . . . . .
	half4 DownsampleBox13Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
	{
		// UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, -1.0))

		half4 A = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, -1.0)));
		half4 B = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.0, -1.0)));
		half4 C = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, -1.0)));
		half4 D = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-0.5, -0.5)));
		half4 E = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.5, -0.5)));
		half4 F = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, 0.0)));
		half4 G = SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv ));
		half4 H = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, 0.0)));
		half4 I = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-0.5, 0.5)));
		half4 J = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.5, 0.5)));
		half4 K = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, 1.0)));
		half4 L = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.0, 1.0)));
		half4 M = SAMPLE_TEXTURE2D(tex, samplerTex,
		                           UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, 1.0)));

		half2 div = (1.0 / 4.0) * half2(0.5, 0.125);

		half4 o = (D + E + I + J) * div.x;
		o += (A + B + G + F) * div.y;
		o += (B + C + H + G) * div.y;
		o += (F + G + L + K) * div.y;
		o += (G + H + M + L) * div.y;

		return o;
	}

	// Standard box filtering
	half4 DownsampleBox4Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
	{
		float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

		half4 s;
		s = (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)));

		return s * (1.0 / 4.0);
	}


	// 9-tap bilinear upsampler (tent filter)
	half4 UpsampleTent(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
	{
		//UnityStereoTransformScreenSpaceTex(uv - d.xy)

		float4 d = texelSize.xyxy * float4(1.0, 1.0, -1.0, 0.0) * sampleScale;

		half4 s;
		s = SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.xy));
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.wy)) * 2.0;
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.zy));

		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)) * 2.0;
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv )) * 4.0;
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)) * 2.0;

		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy));
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.wy)) * 2.0;
		s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy));

		return s * (1.0 / 16.0);
	}

	// Standard box filtering
	half4 UpsampleBox(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
	{
		float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0) * (sampleScale * 0.5);

		half4 s;
		s = (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)));
		s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)));

		return s * (1.0 / 4.0);
	}

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