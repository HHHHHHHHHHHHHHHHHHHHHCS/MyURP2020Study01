Shader "MyRP/UnityChanSSU/4_MySMAA_Final"
{
	HLSLINCLUDE
	#pragma exclude_renderers d3d11_9x gles
	#define filePath "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/SubpixelMorphologicalAntialiasingBridge.hlsl"
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		// 0 - Edge detection (Low)
		Pass
		{
			Name "Edge detection (Low)"

			HLSLPROGRAM
			#pragma vertex VertEdge
			#pragma fragment FragEdge

			#define SMAA_PRESET_LOW
			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}

        // 1 - Edge detection (Medium)
		Pass
		{
			Name "Edge detection (Medium)"

			HLSLPROGRAM
			#pragma vertex VertEdge
			#pragma fragment FragEdge

			#define SMAA_PRESET_MEDIUM
			#include "4_MySMAABridge_Final.hlsl"
			
			ENDHLSL
		}


		// 2 - Edge detection (High)
		Pass
		{
			Name "Edge detection (High)"

			HLSLPROGRAM
			#pragma vertex VertEdge
			#pragma fragment FragEdge

			#define SMAA_PRESET_HIGH
			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}

		// 3 - Blend Weights Calculation (Low)
		Pass
		{
			Name "3 - Blend Weights Calculation (Low)"

			HLSLPROGRAM
			#pragma vertex VertBlend
			#pragma fragment FragBlend

			#define SMAA_PRESET_LOW
			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}

		// 4 - Blend Weights Calculation (Medium)
		Pass
		{
			Name "Blend Weights Calculation (Medium)"

			HLSLPROGRAM
			#pragma vertex VertBlend
			#pragma fragment FragBlend

			#define SMAA_PRESET_MEDIUM
			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}

		// 5 - Blend Weights Calculation (High)
		Pass
		{
			Name "Blend Weights Calculation (High)"

			HLSLPROGRAM
			#pragma vertex VertBlend
			#pragma fragment FragBlend

			#define SMAA_PRESET_HIGH
			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}

		// 6 - Neighborhood Blending
		Pass
		{
			Name "Neighborhood Blending"

			HLSLPROGRAM
			#pragma vertex VertNeighbor
			#pragma fragment FragNeighbor

			#include "4_MySMAABridge_Final.hlsl"
			ENDHLSL
		}
	}
}