Shader "MyRP/LitSamples/06_LitPhysicallyBased"
{
	//这个可能需要自己写editor gui
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
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" /*"RenderPipeline" = "UniversalRenderPipeline"*/ }
		
		HLSLINCLUDE
		
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		CBUFFER_START(UnityPerMaterial)
		float4 _BaseMap_ST;
		half4 _BaseColor;
		half _Metallic;
		half _AmbientOcclusion;
		half _Reflectance;
		half _Smoothness;
		half4 _Emission;
		half _NormalMapScale;
		CBUFFER_END
		
		ENDHLSL
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			#pragma vertex SurfaceVertex
			#pragma fragment SurfaceFragment
			
			// Material Keywords
			#pragma shader_feature_local _NORMALMAP
			
			// Universal Render Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			
			#include "CustomShading.hlsl"
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			TEXTURE2D(_MetallicSmoothnessMap);
			TEXTURE2D(_AmbientOcclusionMap);
			
			void SurfaceFunction(Varyings IN, out CustomSurfaceData surfaceData)
			{
				surfaceData = (CustomSurfaceData)0;
				float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				
				half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb * _BaseColor.rgb;
				half4 metallicSmoothness = SAMPLE_TEXTURE2D(_MetallicSmoothnessMap, sampler_BaseMap, uv);
				half metallic = _Metallic * metallicSmoothness.r;
				// diffuse color is black for metals and baseColor for dieletrics
				surfaceData.diffuse = ComputeDiffuseColor(baseColor.rgb, metallic);
				
				// f0 is reflectance at normal incidence. we store f0 in baseColor for metals.
				// for dieletrics f0 is monochromatic and stored in reflectance value.
				// Remap reflectance to range [0, 1] - 0.5 maps to 4%, 1.0 maps to 16% (gemstone)
				// https://google.github.io/filament/Filament.html#materialsystem/parameterization/standardparameters
				surfaceData.reflectance = ComputeFresnel0(baseColor.rgb, metallic, _Reflectance * _Reflectance * 0.16);
				surfaceData.ao = SAMPLE_TEXTURE2D(_AmbientOcclusionMap, sampler_BaseMap, uv).g * _AmbientOcclusion;
				surfaceData.perceptualRoughness = 1.0 - (_Smoothness * metallicSmoothness.a);
				
				#ifdef _NORMALMAP
					surfaceData.normalWS = GetPerPixelNormalScaled(TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), uv, IN.normalWS, IN.tangentWS, _NormalMapScale);
				#else
					surfaceData.normalWS = normalize(IN.normalWS);
				#endif
				surfaceData.emission = _Emission.rgb;
				surfaceData.alpha = 1.0;
			}
			
			
			ENDHLSL
			
		}
		
		Pass
		{
			
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			
			ColorMask 0
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float3 normalOS: NORMAL;
				float2 texcoord: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
			};
			
			float3 _LightDirection;
			
			
			float4 GetShadowPositionHClip(a2v input)
			{
				float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
				float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
				
				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
				
				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				
				return positionCS;
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.positionHCS = GetShadowPositionHClip(v);
				return o;
			}
			
			
			half4 frag(v2f v): SV_Target
			{
				return 0;
			}
			
			ENDHLSL
			
		}
		
		Pass
		{
			Name "DpethOnly"
			Tags { "LightMode" = "DepthOnly" }
			
			ColorMask 0
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			struct a2v
			{
				float4 positionOS: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
			};
			
			v2f vert(a2v v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
				return o;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				return 0;
			}
			
			ENDHLSL
			
		}
		
		Pass
		{
			//不用normap参计算
			Name "DepthNormals"
			Tags { "LightMode" = "DepthNormals" }
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float4 tangentOS: TANGENT;
				float3 normalOS: NORMAL;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float3 normalWS: TEXCOORD0;
			};
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				
				o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
				VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);
				o.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
				
				return o;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				return float4(PackNormalOctRectEncode(TransformWorldToViewDir(i.normalWS, true)), 0.0, 0.0);
			}
			
			ENDHLSL
			
		}
		
		Pass
		{
			Name "Meta"
			Tags { "LightMode" = "Meta" }
			
			Cull Off
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			// Material Keywords
			#pragma shader_feature_local _NORMALMAP
			
			// #pragma shader_feature_local_fragment _SPECULAR_SETUP
			// #pragma shader_feature_local_fragment _EMISSION
			// #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
			// #pragma shader_feature_local_fragment _ALPHATEST_ON
			// #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			// #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
			
			// #pragma shader_feature_local_fragment _SPECGLOSSMAP
			
			#include "Packages\com.unity.render-pipelines.universal\ShaderLibrary\MetaInput.hlsl"
			#include "Packages\com.unity.render-pipelines.universal\ShaderLibrary\Lighting.hlsl"
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float4 tangentOS: TANGENT;
				float3 normalOS: NORMAL;
				float2 uv0: TEXCOORD0;
				float2 uv1: TEXCOORD1;
				float2 uv2: TEXCOORD2;
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float2 uv: TEXCOORD0;
			};
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			TEXTURE2D(_MetallicSmoothnessMap);
			TEXTURE2D(_AmbientOcclusionMap);
			
			v2f vert(a2v v)
			{
				v2f o;
				
				o.positionHCS = MetaVertexPosition(v.positionOS, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST);
				o.uv = TRANSFORM_TEX(v.uv0, _BaseMap);
				
				return o;
			}
			
			//half Alpha(half albedoAlpha, half4 color, half cutoff)
			half Alpha(half albedoAlpha, half4 color)
			{
				// #if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
				// 	half alpha = albedoAlpha * color.a;
				// #else
				// 	half alpha = color.a;
				// #endif
				
				// #if defined(_ALPHATEST_ON)
				// 	clip(alpha - cutoff);
				// #endif
				
				half alpha = albedoAlpha * color.a;
				
				return alpha;
			}
			
			half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
			{
				half4 specGloss;
				
				/*
				#ifdef _METALLICSPECGLOSSMAP
					specGloss = SAMPLE_METALLICSPECULAR(uv);
					#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
						specGloss.a = albedoAlpha * _Smoothness;
					#else
						specGloss.a *= _Smoothness;
					#endif
				#else  //_METALLICSPECGLOSSMAP
					#if _SPECULAR_SETUP
						specGloss.rgb = _SpecColor.rgb;
					#else
						specGloss.rgb = _Metallic.rrr;
					#endif
					
					#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
						specGloss.a = albedoAlpha * _Smoothness;
					#else
						specGloss.a = _Smoothness;
					#endif
				#endif
				*/
				
				specGloss = SAMPLE_TEXTURE2D(_MetallicSmoothnessMap, sampler_BaseMap, uv);
				specGloss.a *= _Smoothness;
				
				return specGloss;
			}
			
			half3 SampleNormal(float2 uv, TEXTURE2D_PARAM(normalMap, sampler_normalMap), half scale = 1.0h)
			{
				#ifdef _NORMALMAP
					half4 n = SAMPLE_TEXTURE2D(normalMap, sampler_normalMap, uv);
					#if BUMP_SCALE_NOT_SUPPORTED
						return UnpackNormal(n);
					#else
						return UnpackNormalScale(n, scale);
					#endif
				#else
					return half3(0.0h, 0.0h, 1.0h);
				#endif
			}
			
			
			inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
			{
				/*
				half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
				outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
				
				half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
				outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
				
				#if _SPECULAR_SETUP
					outSurfaceData.metallic = 1.0h;
					outSurfaceData.specular = specGloss.rgb;
				#else
					outSurfaceData.metallic = specGloss.r;
					outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
				#endif
				
				outSurfaceData.smoothness = specGloss.a;
				outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
				outSurfaceData.occlusion = SampleOcclusion(uv);
				outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
				
				#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
					half2 clearCoat = SampleClearCoat(uv);
					outSurfaceData.clearCoatMask = clearCoat.r;
					outSurfaceData.clearCoatSmoothness = clearCoat.g;
				#else
					outSurfaceData.clearCoatMask = 0.0h;
					outSurfaceData.clearCoatSmoothness = 0.0h;
				#endif
				
				#if defined(_DETAIL)
					half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
					float2 detailUv = uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
					outSurfaceData.albedo = ApplyDetailAlbedo(detailUv, outSurfaceData.albedo, detailMask);
					outSurfaceData.normalTS = ApplyDetailNormal(detailUv, outSurfaceData.normalTS, detailMask);
					
				#endif
				*/
				
				half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
				outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor.a);
				
				half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
				outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
				
				outSurfaceData.metallic = specGloss.r;
				outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
				
				
				outSurfaceData.smoothness = specGloss.a;
				outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap), _NormalMapScale);
				outSurfaceData.occlusion = SAMPLE_TEXTURE2D(_AmbientOcclusionMap, sampler_BaseMap, uv).g * _AmbientOcclusion;
				outSurfaceData.emission = _Emission.rgb;
				
				outSurfaceData.clearCoatMask = 0.0h;
				outSurfaceData.clearCoatSmoothness = 0.0h;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				SurfaceData surfaceData;
				InitializeStandardLitSurfaceData(i.uv, surfaceData);
				
				BRDFData brdfData;
				InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);
				
				MetaInput metaInput;
				metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
				metaInput.SpecularColor = surfaceData.specular;
				metaInput.Emission = surfaceData.emission;
				
				return MetaFragment(metaInput);
			}
			
			ENDHLSL
			
		}
	}
}
