Shader "MyRP/UnityChanSSU/4_StylizedTonemapFinal"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "4_PostProcessCommon_Final.hlsl"
	ENDHLSL
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		//0. StylizedTonemapFinal
		Pass
		{
			Name "StylizedTonemapFinal"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			TEXTURE2D(_SrcTex);
			SAMPLER(sampler_SrcTex);
			float _Exposure;
			float _Saturation;
			float _Contrast;

			// Reference: https://github.com/EpicGames/UnrealEngine/blob/release/Engine/Shaders/Private/PostProcessCombineLUTs.usf
			float3 ColorCorrect(float3 color, float saturation, float contrast, float exposure)
			{
				float luma = Luminance(color);
				color = max(0, lerp(luma, color, saturation));
				color = pow(color * (1.0 / 0.18), contrast) * 0.18;
				color = color * pow(2.0, exposure);
				return color;
			}

			// ACES tone mapping curve fit to go from HDR to LDR
			// Reference: https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
			float3 ACESFilm(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
			}

			half4 frag(v2f IN):SV_Target
			{
				float4 color = SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, IN.uv);
				color.rgb = ColorCorrect(color.rgb, _Saturation, _Contrast, _Exposure);
				color.rgb = ACESFilm(color.rgb);
				return color;
			}
			ENDHLSL
		}

		//1.Blit
		Pass
		{
			Name "Blit"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			TEXTURE2D(_SrcTex);
			SAMPLER(sampler_Point_Clamp);

			half4 frag(v2f IN):SV_Target
			{
				return SAMPLE_TEXTURE2D(_SrcTex, sampler_Point_Clamp, IN.uv);
			}
			ENDHLSL
		}
	}
}