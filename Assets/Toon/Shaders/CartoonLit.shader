Shader "MyRP/Cartoon/CartoonLit"
{
	Properties
	{
		[HDR] _ToonShadedColor ("Toon Shaded Color", Color) = (0.5019608, 0.3019608, 0.05882353, 1)
		[HDR] _ToonLitColor ("Toon Lit Color", Color) = (0.9245283, 0.6391348, 0.2921858, 1)
		_ToonColorSteps ("Toon Color Steps", Range(1, 10)) = 9
		_ToonColorOffset ("Toon Color Offset", Range(-1, 1)) = 0.3
		_ToonColorSpread ("Toon Color Spread", Range(0, 1)) = 0.96
		_ToonSpecularColor ("Toon Specular Color", Color) = (0.9528302, 0.9528302, 0.9528302, 0)
		_ToonHighlightIntensity ("Toon Highlight Intensity", Range(0, 0.25)) = 0.05
		_OutlineDepthSensitivity ("Outline Depth Sensitivity", Float) = 0.025
		_OutlineNormalSensitivity ("Outline Normal Sensitivity", Float) = 2
		_OutlineThickness ("Outline Thickness", Int) = 1
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
		
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite On
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			
			#pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			
			#define _NORMALMAP 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			// #define ATTRIBUTES_NEED_TEXCOORD1
			// #define VARYINGS_NEED_POSITION_WS
			// #define VARYINGS_NEED_NORMAL_WS
			// #define VARYINGS_NEED_TANGENT_WS
			// #define VARYINGS_NEED_VIEWDIRECTION_WS
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			#include "CommonFunction.hlsl"
			#include "MainLight.hlsl"
			#include "OutlineObject.hlsl"
			#include "MyCarToonPBR.hlsl"
			
			struct a2v
			{
				float4 vertex: POSITION;
				float4 normal: NORMAL;
				float4 tangent: TANGENT;
				float2 uv: TEXCOORD0;
				float2 lightmapUV: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 normalWS: NORMAL;
				float4 tangentWS: TANGENT;
				float3 positionWS: TEXCOORD0;
				float2 uv: TEXCOORD1;
				float2 lightmapUV: TEXCOORD2;
				float3 viewDirectionWS: TEXCOORD3;
				float4 screenUV: TEXCOORD4;
				float3 sh: TEXCOORD5;
				half4 fogFactorAndVertexLight: TEXCOORD6;
				float4 shadowCoord: TEXCOORD7;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			TEXTURE2D(_SSAO_FinalTexture);
			SAMPLER(sampler_SSAO_FinalTexture);
			//                TEXTURE2D(_SSAO_OcclusionTexture3); SAMPLER(sampler_SSAO_OcclusionTexture3); float4 _SSAO_OcclusionTexture3_TexelSize;
			
			CBUFFER_START(UnityPerMaterial)
			float4 _ToonShadedColor;
			float4 _ToonLitColor;
			float _ToonColorSteps;
			float _ToonColorOffset;
			float _ToonColorSpread;
			float4 _ToonSpecularColor;
			float _ToonHighlightIntensity;
			float _OutlineDepthSensitivity;
			float _OutlineNormalSensitivity;
			int _OutlineThickness;
			CBUFFER_END
			
			float4 ToonLighting(v2f i)
			{
				half3 lightDirection;
				half3 lightColor;
				half distanceAtten;
				half shadowAtten;
				MainLight_half(i.positionWS, lightDirection, lightColor, distanceAtten, shadowAtten);
				
				//------
				float lerpVal = saturate(dot(i.normalWS, lightDirection)) * shadowAtten;
				lerpVal = smoothstep(_ToonColorOffset -_ToonColorSpread, _ToonColorOffset +_ToonColorSpread, lerpVal);
				float steps = _ToonColorSteps - 1;
				lerpVal = floor(lerpVal / (1 / steps)) * (1 / steps);
				
				//------
				float3 halfDir = normalize(lightDirection + i.viewDirectionWS);
				float d = dot(halfDir, i.normalWS);
				d = step(1 - _ToonHighlightIntensity, d);
				
				//------
				float4 finalColor = lerp(_ToonShadedColor, _ToonLitColor, lerpVal);
				finalColor = lerp(finalColor, _ToonSpecularColor, d);
				
				return finalColor;
			}
			
			float4 Outlines(v2f i)
			{
				float4 screenPosition = float4(i.screenUV.xy / i.screenUV.w, 0, 0);
				float outline;
				float sceneDepth;
				Outlineobject_float(screenPosition.xy, _OutlineThickness, _OutlineDepthSensitivity, _OutlineNormalSensitivity, outline, sceneDepth);
				float4 outlineColor = float4(1, 1, 1, 1);
				float4 normalColor = float4(0, 0, 0, 1);
				float4 finalColor = lerp(outlineColor, normalColor, outline);
				return finalColor;
			}
			
			float AmbientOcclusion(v2f i)
			{
				float4 screenPosition = float4(i.screenUV.xy / i.screenUV.w, 0, 0);
				float ao = 1 - SAMPLE_TEXTURE2D(_SSAO_FinalTexture, sampler_SSAO_FinalTexture, screenPosition.xy).r;
				return ao;
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.normalWS = TransformObjectToWorldNormal(v.normal.xyz);
				o.tangentWS = float4(TransformObjectToWorldDir(v.tangent.xyz), v.tangent.w);
				o.positionCS = TransformWorldToHClip(o.positionWS);
				o.uv = v.uv;
				o.viewDirectionWS = GetWorldSpaceViewDir(o.positionWS);
				o.screenUV = ComputeScreenPos(o.positionCS, _ProjectionParams.x);
				
				//LightmapUV and SH
				OUTPUT_LIGHTMAP_UV(v.lightUV, unity_LightmapST, o.lightmapUV);
				OUTPUT_SH(o.normalWS, o.sh);
				
				//Fog and vertexLight
				half3 vertexLight = VertexLighting(o.positionWS, o.normalWS);
				half fogFactor = ComputeFogFactor(o.positionCS.z);
				o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
				
				//shadowCoord
				o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				i.normalWS = normalize(i.normalWS);
				
				MyInputData inputData = (MyInputData)0;
				inputData.positionWS = i.positionWS;
				inputData.normalWS = i.normalWS;
				inputData.viewDirectionWS = i.viewDirectionWS;
				inputData.shadowCoord = i.shadowCoord;
				inputData.fogCoord = i.fogFactorAndVertexLight.x;
				inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
				inputData.bakedGI = SAMPLE_GI(i.lightmapUV, i.sh, i.normalWS);
				inputData.normalizedScreenSpaceUV = i.positionCS.xy;
				
				//TODO:
				float4 lightingColor = ToonLighting(i);
				float4 outlineColor = 1;//Outlines(i);
				float ao = 1;//AmbientOcclusion(i);
				
				MySurfaceData surfaceData = (MySurfaceData)0;
				surfaceData.albedo = half3(0, 0, 0);
				surfaceData.specular = half3(0, 0, 0);
				surfaceData.metallic = 0;
				surfaceData.smoothness = 0;
				surfaceData.normalTS = float3(0.0f, 0.0f, 1.0f);
				surfaceData.emission = (lightingColor * outlineColor * ao).rgb;
				surfaceData.occlusion = 0.52;
				surfaceData.alpha = 1;
				surfaceData.clearCoatMask = 0.0;
				surfaceData.clearCoatSmoothness = 1.0;
				
				float4 col = CalcPBRColor(inputData, surfaceData);
				
				return col;
			}
			ENDHLSL
			
		}
		
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			// Defines
			#define _NORMALMAP 1
			// #define _NORMAL_DROPOFF_TS 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			// #define FEATURES_GRAPH_VERTEX
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			struct a2v
			{
				float3 positionOS: POSITION;
				float3 normalOS: NORMAL;
				//float4 tangentOS: TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			// x: global clip space bias, y: normal world space bias
			float3 _LightDirection;
			
			v2f vert(a2v v)
			{
				v2f o = (v2f)0;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				float3 positionWS = TransformObjectToWorld(v.positionOS);
				float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
				o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
				//根据是否进行了Z反向（比如unity编辑器下是DX11，是有Z反向的)
				#if UNITY_REVERSED_Z
					o.positionCS.z = min(o.positionCS.z, o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
					o.positionCS.z = MAX(o.positionCS.z, o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				
				return o;
			}
			
			float4 frag(v2f i): SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				return 0;
			}
			
			ENDHLSL
			
		}
	}
}
