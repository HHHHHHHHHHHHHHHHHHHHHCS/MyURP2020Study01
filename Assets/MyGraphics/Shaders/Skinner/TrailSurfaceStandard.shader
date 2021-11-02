Shader "MyRP/Skinner/TrailSurfaceStandard"
{
	Properties
	{
		_Albedo("Albedo", Color) = (0.5, 0.5, 0.5)
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		_Metallic("Metallic", Range(0, 1)) = 0

		[Header(Self Illumination)]
		_BaseHue("Base Hue", Range(0, 1)) = 0
		_HueRandomness("Hue Randomness", Range(0, 1)) = 0.2
		_Saturation("Saturation", Range(0, 1)) = 1
		_Brightness("Brightness", Range(0, 6)) = 0.8
		_EmissionProb("Probability", Range(0, 1)) = 0.2

		[Header(Color Modifier (By Speed))]
		_CutoffSpeed("Cutoff Speed", Float) = 0.5
		_SpeedToIntensity("Sensitivity", Float) = 1
		_BrightnessOffs("Brightness Offset", Range(0, 6)) = 1.0
		_HueShift("Hue Shift", Range(-1, 1)) = 0.2
	}
	HLSLINCLUDE
	ENDHLSL
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry"
		}

		Cull Off
		//ZTest Always

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex ForwardLitVert
			#pragma fragment ForwardLitFrag


			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON

			// Keywords
			#pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			
			#define ForwardLitPass

			#include "TrailSurfaceCommon.hlsl"
			
			ENDHLSL
		}


		Pass
		{
			Name "ShadowCaster"
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			HLSLPROGRAM
			#pragma vertex ShadowCasterVert
			#pragma fragment ShadowCasterFrag

			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#define ShadowCasterPass
			
			#include "TrailSurfaceCommon.hlsl"
			
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags
			{
				"LightMode" = "DepthOnly"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma vertex DepthOnlyVert
			#pragma fragment DepthOnlyFrag

			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			#define DepthOnlyPass
			
			#include "TrailSurfaceCommon.hlsl"

			ENDHLSL
		}


		Pass
		{
			Tags
			{
				"LightMode" = "MotionVectors"
			}
			Cull Off
			ZWrite Off
			HLSLPROGRAM
			#pragma vertex MotionVectorsVert
			#pragma fragment MotionVectorsFrag

			#define MotionVectorsPass
			
			#include "TrailSurfaceCommon.hlsl"
			
			ENDHLSL
		}
	}
}