Shader "MyRP/FastPostProcessing/FastPostProcessing"
{
	Properties
	{
	}

	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	#pragma multi_compile_local _ _SHARPEN
	#pragma multi_compile_local _ _BLOOM
	#pragma multi_compile_local _ _TONEMAPPER_ACES _TONEMAPPER_DAWSON _TONEMAPPER_HABLE _TONEMAPPER_PHOTOGRAPHIC _TONEMAPPER_REINHART
	#pragma multi_compile_local _ _DITHERING
	#pragma multi_compile_local _ _USERLUT_ENABLE
	#pragma multi_compile_local _ _GAMMA_CORRECTION
	TEXTURE2D(_MainTex);
	SAMPLER(sampler_MainTex);
	float4 _MainTex_TexelSize;

	#ifdef _SHARPEN
		float _SharpenSize;
		float _SharpenIntensity;
	#endif

	#ifdef _BLOOM
		float _BloomSize;
		float _BloomAmount;
		float _BloomPower;
	#endif

	#if defined(_TONEMAPPER_ACES) || defined(_TONEMAPPER_DAWSON) || defined(_TONEMAPPER_HABLE) || defined(_TONEMAPPER_PHOTOGRAPHIC) || defined(_TONEMAPPER_REINHART)
		float _Exposure;
	#endif

	#ifdef _USERLUT_ENABLE
		TEXTURE2D(_UserLutTex);
		SAMPLER(sampler_UserLutTex);
		float4 _UserLutParams;
	#endif


	struct a2v
	{
		uint vertexID : SV_VertexID;
	};

	struct v2f
	{
		float4 pos: SV_POSITION;
		float2 uv: TEXCOORD0;
	};

	v2f vert(a2v v)
	{
		v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
		return o;
	}

	half4 TexMainTex2D(float2 uv)
	{
		return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
	}

	#ifdef _TONEMAPPER_ACES
		half3 TonemapACES(half3 color)
		{
			color *= _Exposure;
			const half3 a = 2.51;
			const half3 b = 0.03;
			const half3 c = 2.43;
			const half3 d = 0.59;
			const half3 e = 0.14;
			return saturate((color * (a * color + b)) / (color * (c * color + d) + e));
		}
	#endif

	#ifdef _TONEMAPPER_DAWSON
		half3 TonemapDAWSON(half3 color)
		{
			const half3 a = 6.2;
			const half3 b = 0.5;
			const half3 c = 1.7;
			const half3 d = 0.06;
			
			color *= _Exposure;
			color = max(0, color - 0.004);
			color = (color * (a * color + b)) / (color * (a * color + c) + d);
			return color * color;
		}
	#endif

	#ifdef _TONEMAPPER_HABLE
		half3 TonemapHable(half3 color)
		{
			const half a = 0.15;
			const half b = 0.50;
			const half c = 0.10;
			const half d = 0.20;
			const half e = 0.02;
			const half f = 0.30;
			const half w = 11.2;
			
			color *= _Exposure * 2.0;
			half3 curr = ((color * (a * color + c * b) + d * e) / (color * (a * color + b) + d * f)) - e / f;
			color = w;
			half3 whiteScale = 1.0 / (((color * (a * color + c * b) + d * e) / (color * (a * color + b) + d * f)) - e / f);
			return curr * whiteScale;
		}
	#endif

	#ifdef _TONEMAPPER_PHOTOGRAPHIC
		half3 TonemapPhotographic(half3 color)
		{
			color *= _Exposure;
			return 1.0 - exp2(-color);
		}
	#endif

	#ifdef _TONEMAPPER_REINHART
		half3 TonemapReinhard(half3 color)
		{
			half lum = Luminance(color);
			half lumTm = lum * _Exposure;
			half scale = lumTm / (1.0 + lumTm);
			return color * scale / lum;
		}
	#endif

	#ifdef _USERLUT_ENABLE
		half3 ApplyLUT(float3 col, float3 scaleOffset)
		{
			col.z *= scaleOffset.z;
			float shift = floor(col.z);
			col.xy = scaleOffset.xy * (col.xy * scaleOffset.z + 0.5);
			col.x += shift * scaleOffset.y;
			
			half3 col0 = SAMPLE_TEXTURE2D(_UserLutTex, sampler_UserLutTex, col.xy);
			half3 col1 = SAMPLE_TEXTURE2D(_UserLutTex, sampler_UserLutTex, col.xy + float2(scaleOffset.y, 0));
			
			return lerp(col0, col1, col.z - shift);
		}
	#endif

	half4 frag(v2f i): SV_TARGET
	{
		half2 uv = i.uv;

		half4 colAlpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

		half3 col = colAlpha.rgb;

		#if _SHARPEN
			col -= TexMainTex2D(uv + _SharpenSize).rgb * 7.0 * _SharpenIntensity;
			col += TexMainTex2D(uv + _SharpenSize).rgb * 7.0 * _SharpenIntensity;
		#endif

		#if _BLOOM
			float size = 1 / _BloomSize;
			float4 sum = 0;
			float3 bloom;
			
			for (int i = -1; i < 3; ++ i)
			{
				sum += TexMainTex2D(uv + float2(-1, i) * size) ;
				sum += TexMainTex2D(uv + float2(0, i) * size) ;
				sum += TexMainTex2D(uv + float2(+1, i) * size) ;
			}
			
			sum *= _BloomAmount;
			
			float luminnace = Luminance(col);
			bloom = sum.rgb * sum.rgb * lerp(0.0075, 0.012, luminnace) + col;
			col = lerp(col, bloom, _BloomPower);
			
		#endif


		#if TONEMAPPER_ACES
			col = tonemapACES(col);
		#elif TONEMAPPER_DAWSON
			col = tonemapHejlDawson(col);
		#elif TONEMAPPER_HABLE
			col = tonemapHable(col);
		#elif TONEMAPPER_PHOTOGRAPHIC
			col = tonemapPhotographic(col);
		#elif TONEMAPPER_REINHART
			col = tonemapReinhard(col);
		#endif

		#if _DITHERING
			// Interleaved Gradient Noise from http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare (slide 122)
			half3 magic = float3(0.06711056, 0.00583715, 52.9829189);
			half gradient = frac(magic.z * frac(dot(uv / _MainTex_TexelSize.xy, magic.xy))) / 255.0;
			col.rgb -= gradient.xxx;
		#endif

		#if _USERLUT_ENABLE
			half3 lc = ApplyLUT(saturate(col.rgb), _UserLutParams.xyz);
			col = lerp(col, lc, _UserLutParams.w);
		#endif

		#if _GAMMA_CORRECTION
			col = pow(col, 2.2);
		#endif


		return half4(col, colAlpha.a);
	}
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDHLSL

		}
	}
}