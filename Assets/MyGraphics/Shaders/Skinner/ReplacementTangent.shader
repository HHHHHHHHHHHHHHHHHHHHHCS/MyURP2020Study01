Shader "MyRP/Skinner/ReplacementTangent"
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
			#define SKINNER_TANGENT
			#include "Replacement.hlsl"
			ENDHLSL
		}
	}
}