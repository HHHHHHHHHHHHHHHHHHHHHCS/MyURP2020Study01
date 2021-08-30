Shader "MyRP/Skinner/ReplacementNormal"
{
	SubShader
	{
		Tags
		{
			"Skinner" = "Source"
		}
		Pass
		{
			ZTest Always ZWrite Off
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#define SKINNER_NORMAL
			#include "Replacement.hlsl"
			ENDHLSL
		}
	}
}