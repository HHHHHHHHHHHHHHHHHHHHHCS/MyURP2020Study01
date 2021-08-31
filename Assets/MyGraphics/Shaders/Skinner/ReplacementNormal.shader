Shader "MyRP/Skinner/ReplacementNormal"
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
			#define SKINNER_NORMAL
			#include "Replacement.hlsl"
			ENDHLSL
		}
	}
}