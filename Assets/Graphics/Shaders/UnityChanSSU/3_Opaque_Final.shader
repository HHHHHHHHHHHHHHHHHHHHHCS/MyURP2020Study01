Shader "MyRP/UnityChanSSU/3_Opaque_Final"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_GradientMap ("Gradient Map", 2D) = "white" {}

		_ShadowColor1stTex ("1st Shadow Color Tex", 2D) = "white" {}
		_ShadowColor1st ("1st Shadow Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_ShadowColor2ndTex ("2nd Shadow Color Tex", 2D) = "white" {}
		_ShadowColor2nd ("2nd Shadow Color", Color) = (1.0, 1.0, 1.0, 1.0)

		[HDR] _SpecularColor ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_SpecularPower ("Specular Power", Float) = 20.0

		_RimLightMask ("Rim Light Mask", 2D) = "white" {}
		[HDR] _RimLightColor ("Rim Light Color", Color) = (0.0, 0.0, 0.0, 1.0)
		_RimLightPower ("Rim Light Power", Float) = 20.0

		_OutlineWidth ("Outline Width", Range(0.0, 3.0)) = 1.0
		_OutlineColor ("Outline Color", Color) = (0.2, 0.2, 0.2, 1.0)
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "3_ShadingCommon_Final.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "Outline"
			Tags
			{
				"LightMode" = "Outline"
			}

			Cull Front

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "3_OutlineCommon_Final.hlsl"

			ENDHLSL
		}
	}
}