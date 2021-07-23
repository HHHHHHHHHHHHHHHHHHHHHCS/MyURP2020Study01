Shader "MyRP/UnityChanSSU/4_MyFinal_Final"
{
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			Name "MyFinal"

			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment frag

			#pragma multi_compile_local_fragment _ _FXAA
			#pragma multi_compile_local_fragment _ _DITHERING

			#include "4_PostProcessCommon_Final.hlsl"
			#if _FXAA
				#include "4_FXAA_Final.hlsl"
			#endif
			#if _DITHERING
				#include "4_Dither_Final.hlsl"
			#endif


			half4 frag(v2f IN):SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_SrcTex, sampler_Point_Clamp, IN.uv);

				#if _FXAA
				{
					col.rgb = FXAA(col.rgb, IN.uv, IN.vertex);
	            }
				#endif

				#if _DITHERING
				{
					col.rgb = Dither(col.rgb, IN.uv);
	            }
				#endif


				return col;
			}
			ENDHLSL
		}
	}
}