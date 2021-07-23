Shader "MyRP/LitSamples/05_BakedIndirect"
{
	Properties
	{
		[MainColor] _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("BaseMap", 2D) = "white" { }
		[Normal] _NormalMap ("NormalMap", 2D) = "bump" { }
		_AmbientOcclusion ("AmbientOcclusion", Range(0, 1)) = 1.0
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" /*"RenderPipeline" = "UniversalRenderPipeline"*/ }
		
		HLSLINCLUDE
		
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		CBUFFER_START(UnityPerMaterial)
		float4 _BaseMap_ST;
		half4 _BaseColor;
		half _AmbientOcclusion;
		CBUFFER_END
		
		ENDHLSL
		
		Pass
		{
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			#pragma vertex SurfaceVertex
			#pragma fragment SurfaceFragment
			
			#define CUSTOM_LIGHTING_FUNCTION BakeIndirectLighting
			
			// Universal Render Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT
			
			// Unity defined keywords
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			
			#define _NORMALMAP 1
			
			//可以这样顶层目录开始查找
			//#include "Assets/xxxxxxx"
			#include "CustomShading.hlsl"
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			
			void SurfaceFunction(Varyings IN, out CustomSurfaceData surfaceData)
			{
				float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				
				surfaceData = (CustomSurfaceData)0;
				surfaceData.diffuse = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb * _BaseColor.rgb;
				surfaceData.ao = _AmbientOcclusion;
				#ifdef _NORMALMAP
					surfaceData.normalWS = GetPerPixelNormal(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS);
				#else
					surfaceData.normalWS = normalize(IN.normalWS);
				#endif
				surfaceData.alpha = 1.0;
			}
			
			half4 BakeIndirectLighting(CustomSurfaceData surfaceData, LightingData lightingData)
			{
				return half4(surfaceData.diffuse + lightingData.environmentLighting, surfaceData.alpha);
			}
			
			ENDHLSL
			
		}
		
		UsePass "MyRP/LitSamples/02_UnlitTextureShadows/ShadowCaster"
	}
}
