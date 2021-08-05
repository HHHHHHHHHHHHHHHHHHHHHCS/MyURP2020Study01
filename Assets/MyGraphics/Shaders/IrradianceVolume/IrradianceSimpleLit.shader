// Shader targeted for low end devices. Single Pass Forward Rendering.
//Copy from Shader "Universal Render Pipeline/Simple Lit"
Shader "MyRP/IrradianceVolume/IrradianceSimpleLit"
{
	// Keep properties of StandardSpecular shader for upgrade reasons.
	Properties
	{
		[MainTexture] _BaseMap("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
		[MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)

		_Cutoff("Alpha Clipping", Range(0.0, 1.0)) = 0.5

		_SpecColor("Specular Color", Color) = (0.5, 0.5, 0.5, 0.5)
		_SpecGlossMap("Specular Map", 2D) = "white" {}
		[Enum(Specular Alpha,0,Albedo Alpha,1)] _SmoothnessSource("Smoothness Source", Float) = 0.0
		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0

		[HideInInspector] _BumpScale("Scale", Float) = 1.0
		[NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}

		[HDR] _EmissionColor("Emission Color", Color) = (0,0,0)
		[NoScaleOffset]_EmissionMap("Emission Map", 2D) = "white" {}

		// Blending state
		[HideInInspector] _Surface("__surface", Float) = 0.0
		[HideInInspector] _Blend("__blend", Float) = 0.0
		[HideInInspector] _AlphaClip("__clip", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _Cull("__cull", Float) = 2.0

		[ToggleOff] _ReceiveShadows("Receive Shadows", Float) = 1.0
		[Toggle]_VOLUME_GI("Volume GI", Float) = 0

		// Editmode props
		[HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
		[HideInInspector] _Smoothness("Smoothness", Float) = 0.5

		// ObsoleteProperties
		[HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
		[HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
		[HideInInspector] _Shininess("Smoothness", Float) = 0.0
		[HideInInspector] _GlossinessSource("GlossinessSource", Float) = 0.0
		[HideInInspector] _SpecSource("SpecularHighlights", Float) = 0.0

		[HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
		[HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
		[HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "SimpleLit" "IgnoreProjector" = "True" "ShaderModel"="4.5"
		}
		LOD 300

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			// Use same blending / depth states as Standard shader
			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local_fragment _ _SPECGLOSSMAP _SPECULAR_COLOR
			#pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local_fragment _EMISSION
			#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
			// #pragma shader_feature_local_fragment _VOLUME_GI_ON
			#define _VOLUME_GI_ON
			
			// -------------------------------------
			// Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

			// -------------------------------------
			// Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#pragma multi_compile _ _BAKING

			#pragma vertex LitPassVertexSimple
			#pragma fragment LitPassFragmentSimple
			#define BUMP_SCALE_NOT_SUPPORTED 1

			#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
			#include "IrradianceSimpleLitForwardPass.hlsl"
			ENDHLSL
		}

		UsePass "Universal Render Pipeline/Simple Lit/ShadowCaster"
		UsePass "Universal Render Pipeline/Simple Lit/GBuffer"
		UsePass "Universal Render Pipeline/Simple Lit/DepthOnly"
		UsePass "Universal Render Pipeline/Simple Lit/DepthNormals"
		UsePass "Universal Render Pipeline/Simple Lit/Meta"
		UsePass "Universal Render Pipeline/Simple Lit/Universal2D"
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "SimpleLit" "IgnoreProjector" = "True" "ShaderModel"="2.0"
		}
		LOD 300

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			// Use same blending / depth states as Standard shader
			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			#pragma only_renderers gles gles3 glcore d3d11
			#pragma target 2.0

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
			#pragma shader_feature_local_fragment _ _SPECGLOSSMAP _SPECULAR_COLOR
			#pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local_fragment _EMISSION
			#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
			// #pragma shader_feature_local_fragment _VOLUME_GI_ON
			#define _VOLUME_GI_ON

			
			// -------------------------------------
			// Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION


			// -------------------------------------
			// Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog

			#pragma vertex LitPassVertexSimple
			#pragma fragment LitPassFragmentSimple
			#define BUMP_SCALE_NOT_SUPPORTED 1

			#pragma multi_compile _ _BAKING

			#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
			#include "IrradianceSimpleLitForwardPass.hlsl"
			ENDHLSL
		}

		UsePass "Universal Render Pipeline/Simple Lit/ShadowCaster"
		UsePass "Universal Render Pipeline/Simple Lit/GBuffer"
		UsePass "Universal Render Pipeline/Simple Lit/DepthOnly"
		UsePass "Universal Render Pipeline/Simple Lit/DepthNormals"
		UsePass "Universal Render Pipeline/Simple Lit/Meta"
		UsePass "Universal Render Pipeline/Simple Lit/Universal2D"
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
	// CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.SimpleLitShader"
}