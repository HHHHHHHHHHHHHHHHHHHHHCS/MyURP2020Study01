Shader "MyRP/UnityChanSSU/4_MyBlit_Final"
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
			Name "Blit"

			HLSLPROGRAM
			#pragma vertex VertDefault
			#pragma fragment frag

			SAMPLER(sampler_Point_Clamp);


			half4 frag(v2f IN):SV_Target
			{
				return SAMPLE_TEXTURE2D(_SrcTex, sampler_Point_Clamp, IN.uv);
			}
			ENDHLSL
		}
	}
}