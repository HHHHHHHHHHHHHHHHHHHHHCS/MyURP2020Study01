Shader "MyRP/UnityChanSSU/4_MyUber_Final"
{
	HLSLINCLUDE
	#include "4_PostProcessCommon_Final.hlsl"
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			Name "MyUber"

			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment frag

			#pragma multi_compile _ CHROMATIC_ABERRATION CHROMATIC_ABERRATION_LOW
			#pragma multi_compile _ BLOOM BLOOM_LOW
			#pragma multi_compile _ VIGNETTE

			SAMPLER(sampler_Linear_Clamp);
			SAMPLER(sampler_Point_Clamp);

			// Chromatic aberration
			//-----------------------
			#if CHROMATIC_ABERRATION || CHROMATIC_ABERRATION_LOW
				#define MAX_CHROMATIC_SAMPLES 16

				TEXTURE2D(_ChromaticAberration_SpectralLut);
				half _ChromaticAberration_Amount;
			#endif


			// Bloom
			//-----------------------
			#if BLOOM || BLOOM_LOW
				TEXTURE2D(_BloomTex);
				TEXTURE2D(_Bloom_DirtTex);
				float4 _BloomTex_TexelSize;
				float4 _Bloom_DirtTileOffset; // xy: tiling, zw: offset
				half3 _Bloom_Settings; // x: sampleScale, y: intensity, z: dirt intensity
				half3 _Bloom_Color;
			#endif


			// Vignette
			//-----------------------
			#if VIGNETTE
				half3 _Vignette_Color;
				half2 _Vignette_Center; // UV space
				half4 _Vignette_Settings; // x: intensity, y: smoothness, z: roundness, w: rounded
				half _Vignette_Opacity;
				half _Vignette_Mode; // <0.5: procedural, >=0.5: masked
				TEXTURE2D(_Vignette_Mask);
			#endif


			half4 frag(v2f IN):SV_Target
			{
				float2 uv = IN.uv;

				//我们没有自动曝光
				//half autoExposure = SAMPLE_TEXTURE2D(_AutoExposureTex, sampler_AutoExposureTex, uv).r;
				half4 color = half4(0, 0, 0, 0);


				// Inspired by the method described in "Rendering Inside" [Playdead 2016]
				// https://twitter.com/pixelmager/status/717019757766123520
				#if CHROMATIC_ABERRATION
				{
					float2 coords = 2.0 * uv - 1.0;
					float2 end = uv - coords * dot(coords, coords) * _ChromaticAberration_Amount;

					float2 diff = end - uv;
					int samples = clamp(int(length(_SrcTex_TexelSize.zw * diff / 2.0)), 3, MAX_CHROMATIC_SAMPLES);
					float2 delta = diff / samples;
					float2 pos = uv;
					half4 sum = half4(0, 0, 0, 0);
					half4 filterSum = half4(0, 0, 0, 0);

					for (int i = 0; i < samples; i++)
					{
						half t = (i + 0.5) / samples;
						half4 s = SAMPLE_TEXTURE2D_LOD(_SrcTex, sampler_Point_Clamp,
						                               UnityStereoTransformScreenSpaceTex(pos), 0);
						half4 filter = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_Linear_Clamp,
						                                          float2(t,0), 0).rgb, 1.0);

						sum += s * filter;
						filterSum += filter;
						pos += delta;
					}

					color = sum / filterSum;
				}
				#elif CHROMATIC_ABERRATION_LOW
				{
					float2 coords = 2.0 * uv - 1.0;
					float2 end = uv - coords * dot(coords, coords) * _ChromaticAberration_Amount;
					float2 delta = (end - uv) / 3;

	                half4 filterA = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(0.5 / 3, 0.0), 0).rgb, 1.0);
	                half4 filterB = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(1.5 / 3, 0.0), 0).rgb, 1.0);
	                half4 filterC = half4(SAMPLE_TEXTURE2D_LOD(_ChromaticAberration_SpectralLut, sampler_ChromaticAberration_SpectralLut, float2(2.5 / 3, 0.0), 0).rgb, 1.0);

	                half4 texelA = SAMPLE_TEXTURE2D_LOD(_SrcTex, sampler_Point_Clamp, UnityStereoTransformScreenSpaceTex(Distort(uv)), 0);
	                half4 texelB = SAMPLE_TEXTURE2D_LOD(_SrcTex, sampler_Point_Clamp, UnityStereoTransformScreenSpaceTex(Distort(delta + uv)), 0);
	                half4 texelC = SAMPLE_TEXTURE2D_LOD(_SrcTex, sampler_Point_Clamp, UnityStereoTransformScreenSpaceTex(Distort(delta * 2.0 + uv)), 0);

	                half4 sum = texelA * filterA + texelB * filterB + texelC * filterC;
	                half4 filterSum = filterA + filterB + filterC;
	                color = sum / filterSum;
				}
				#else
					color = SAMPLE_TEXTURE2D(_SrcTex, sampler_Point_Clamp, uv);
				#endif


				return color;
			}
			ENDHLSL
		}
	}
}