Shader "MyRP/UnityChanSSU/3_Transparent_Final"
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
			"RenderType" = "Transparent"  "Queue" = "Transparent" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}
		
		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			Cull Back
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#define IS_TRANSPARENT
			#include "3_ShadingCommon_Final.hlsl"

			ENDHLSL
		}
		
		//用来记录depth 阻止transparent的穿透绘制
		Pass
		{
			Name "TransparentDepth"
			Tags
			{
				"LightMode" = "TransparentDepth"
			}

			ZWrite On
			ColorMask 0
		}

		//因为透明已经记录了深度(要确保先绘制深度 再画轮廓)
		//所以在before transparent 之后绘制outline 再绘制透明物体 也没有什么关系
		//至于为什么?  因为after transparent后面要画别的透明物体 避免出现叠加混乱
		Pass
		{
			Name "Outline"
			Tags
			{
				"LightMode" = "Outline"
			}

			Cull Front
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#define IS_TRANSPARENT
			#include "3_OutlineCommon_Final.hlsl"

			ENDHLSL
		}
	}
}