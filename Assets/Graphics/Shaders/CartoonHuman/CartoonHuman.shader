Shader "MyRP/CartoonHuman/Character"
{
	Properties
	{
		[Toggle(CLOTH_ENABLE)] _ClothEnable ("Cloth Enable", Float) = 0
		
		_Color ("Main Color", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" { }
		_NormalTex ("Normal Tex", 2D) = "bump" { }
		_MaskTex ("Mask Tex(r Metallic, g Ramp Mask, b Roughness, a Rim Mask)", 2D) = "white" { }
		_Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0
		_OcclusionStrength ("Occlusion Strength", Range(0.0, 1.0)) = 1.0
		_Cutoff ("Cut Off Threshold", Range(0, 1)) = 0
		
		[Header(Ramp Setting)]
		_DiffuseRampTex ("Diffuse Ramp Map", 2D) = "gray" { }
		_MultiRampTex ("Multi Ramp Map", 2D) = "gray" { }
		_TintLayer1 ("Tint Layer1", Color) = (1, 1, 1, 1)
		_TintLayer2 ("Tint Layer2", Color) = (1, 1, 1, 1)
		_TintLayer3 ("Tint Layer3", Color) = (1, 1, 1, 1)
		_VerticalCoord ("Vertical Coord", Range(0, 1)) = 1
		_RampOffset ("Ramp Offset", Range(-1, 1)) = 0
		
		[Header(RimLight Setting)]
		[Toggle(RIMLIGHT_ENABLE)] _RimlightEnable ("Rimlight Enable", float) = 1
		_RimRange ("Rim Range", Range(0.01, 1)) = 1
		_RimIntensity ("Rim Intensity", Range(0, 10)) = 1
		_RimColor ("Rim Color", Color) = (1, 1, 1, 1)
		
		[Header(Outline Setting)]
		_VertexTex ("Vertex Map (r offset, g scale)", 2D) = "gray" { }
		_OutlineColor ("OutlineColor", Color) = (0, 0, 0, 1)
		_OutlineWidth ("OutlineWidth", Range(0, 0.1)) = 0.05
		_MaxOutlineZOffset ("MaxOutlineZOffset", Range(0, 1)) = 0
		_Scale ("Scale", Range(0, 0.1)) = 0.01
		
		[Header(Hair Setting)]
		[Toggle(ANISO_ENABLE)] _AnisoEnable ("Aniso Enable", float) = 0
		[Toggle(UV_VERTICAL)] _UVVertical ("_UV Vertical", float) = 0
		_AnisoTex ("Aniso Tex(b Normal Scale, a Specular Mask)", 2D) = "black" { }
		
		_HairNoiseTex ("Hair Noise Tex", 2D) = "gray" { }
		_NoiseScale ("Noise Scale", Range(0, 1)) = 0
		_SpecularRange1 ("Specular Range1", Range(0.001, 2)) = 1
		_SpecularOffset1 ("Specular Offset1", Range(-2, 2)) = 0
		_ChangeLightDir1 ("Change Light Dir1", Vector) = (0, 0, 0, 0)
		_SpecularColor1 ("Specular Color1", Color) = (1, 1, 1, 1)
		_SpecularIntensity1 ("Specular Intensity1", Range(0, 10)) = 1
		
		_SpecularRange2 ("Specular Range2", Range(0.001, 2)) = 1
		_SpecularOffset2 ("Specular Offset2", Range(-2, 2)) = 0
		_ChangeLightDir2 ("Change Light Dir1", Vector) = (0, 0, 0, 0)
		_SpecularColor2 ("Specular Color2", Color) = (0, 0, 0, 0)
		_SpecularIntensity2 ("Specular Intensity2", Range(0, 10)) = 0
		
		[Header(IBL Setting)]
		_IBLIntensity ("IBL Intensity", Range(0, 10)) = 1
		_SpecColor ("Specular Color", Color) = (1, 1, 1, 1)
		_SpecInt ("Specular Intensity", Float) = 1.0
		_Shininess ("Specular Sharpness", Range(2.0, 8.0)) = 4.0
		_Fresnel ("Fresnel Strength", Range(0.0, 1.0)) = 0.0
		
		[Header(Face Red Setting)]
		[Toggle(FACE_RED_ENABLE)] _FaceRedEnable ("Face Red Enable", float) = 0
		_ChangeMaskMap ("Change Mask Map", 2D) = "black" { }
		_ChangeColor ("Change Color", Color) = (0, 0, 0, 0)
		
		
		[Header(Miscellaneous Setting)]
		[Toggle(ENABLE_ALPHATEST)] _AlphaTest ("AlphaTest", Float) = 0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
		_Stencil ("Stencil Value", Float) = 2
		
		[Header(Special Mat Setting)]
		[Toggle(SPECIAL_MAT_ENABLE)] _SpecialMatEnable ("Special Mat Enable", Float) = 0
		_MatMaskMap ("Material Mask", 2D) = "black" { }
		
		[Header(Glitter Setting)]
		_FakeLight ("Fake light", Range(0, 10)) = 0.05
		_GlitterMap ("Glitter map", 2D) = "white" { }
		_GlitterColor ("Glitter color", Color) = (1, 1, 1, 1)
		_GlitterPower ("Glitter power (0 - 10)", Range(0, 10)) = 2
		_GlitterContrast ("Glitter contrast (1 - 3)", Range(1, 3)) = 1.5
		_GlitterySpeed ("Glittery speed (0 - 1)", Range(0, 1)) = 0.5
		_GlitteryMaskScale ("Glittery & mask dots scale", Range(0.1, 8)) = 2.5
		_MaskAdjust ("Mask adjust (0.5 - 1.5)", Range(0.5, 1.5)) = 1
		_GlitterThreshold ("Glitter Threshold", Range(0, 3)) = 0.5
		
		[Header(Gem Setting)]
		_RefractIndex ("Refract Index", Range(0.01, 3)) = 1
		_GemInnerTex ("Gem Inner Tex", 2D) = "black" { }
		
		[Header(Emission Setting)]
		_EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)
		_EmissionIntensity ("Emission Intensity", Range(0, 100)) = 1
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" /*"RenderPipeline"="UniversalPipeline"*/ }
		
		/*
		Stencil
		{
			Ref [_Stencil]
			Comp Always
			Pass Replace
		}
		*/

		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			

			ENDHLSL
		}
	}
}
