Shader "MyRP/LitSamples/06_LitPhysicallyBased"
{
	Properties
	{
		[Header(Surface)]
		[MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("Base Map", 2D) = "white" { }
		
		_Metallic ("Metallic", Range(0, 1)) = 1.0
		[NoScaleOffset]_MetallicSmoothnessMap ("MetalicMap", 2D) = "white" { }
		_AmbientOcclusion ("AmbientOcclusion", Range(0, 1)) = 1.0
		[NoScaleOffset]_AmbientOcclusionMap ("AmbientOcclusionMap", 2D) = "white" { }
		_Reflectance ("Reflectance for dieletrics", Range(0.0, 1.0)) = 0.5
		_Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.5
		
		[Toggle(_NORMALMAP)] _EnableNormalMap ("Enable Normal Map", Float) = 0.0
		[Normal][NoScaleOffset]_NormalMap ("Normal Map", 2D) = "bump" { }
		_NormalMapScale ("Normal Map Scale", Float) = 1.0
		
		[Header(Emission)]
		[HDR]_Emission ("Emission Color", Color) = (0, 0, 0, 1)
	}
}
