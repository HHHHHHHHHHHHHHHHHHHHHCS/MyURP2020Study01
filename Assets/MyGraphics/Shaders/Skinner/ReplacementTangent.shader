Shader "MyRP/Skinner/ReplacementTangent"
{
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry" "LightMode"="SkinnerSource"
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