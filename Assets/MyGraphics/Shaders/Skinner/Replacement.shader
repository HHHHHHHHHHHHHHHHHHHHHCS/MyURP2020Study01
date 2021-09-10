Shader "MyRP/Skinner/Replacement"
{
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry" "LightMode"="SkinnerSource"
		}
		Pass
		{
			ZTest Always 
			ZWrite Off
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#define SKINNER_POSITION
			#define SKINNER_NORMAL
			#define SKINNER_TANGENT
			#define SKINNER_MRT
			#include "Replacement.hlsl"
			ENDHLSL
		}
	}
}