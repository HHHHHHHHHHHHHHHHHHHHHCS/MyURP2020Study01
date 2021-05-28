Shader "MyRP/UnityChanSSU/4_MyFinal_Final"
{
	HLSLINCLUDE
	#include "4_PostProcessCommon_Final.hlsl"
	#include "4_Dither_Final.hlsl"
	ENDHLSL

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

			half4 frag(v2f IN):SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_SrcTex, sampler_Point_Clamp, IN.uv);

				col.rgb = Dither(col.rgb, IN.uv);

				return col;
			}
			ENDHLSL
		}
	}
}