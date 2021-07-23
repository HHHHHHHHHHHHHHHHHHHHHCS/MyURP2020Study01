Shader "MyRP/XPostProcessing/Blit"
{
	Properties
	{
	}
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

			#include "XPostProcessingLib.hlsl"

			half4 DoEffect(v2f IN)
			{
				return SampleSrcTex(IN.uv);
			}
			ENDHLSL
		}

	}
}