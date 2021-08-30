Shader "MyRP/CartoonWater/CartoonWaterLit"
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
		[Toggle(_DetailAlphaX_ON)]DetailAlphaX ("Detail Alpha X", Int) = 1
		_DetailDensity ("Detail Density", Float) = 3
		_DetailScale ("Detail Scale", Vector) = (1, 0.2, 0, 0)
		_DetailNoiseStrength ("Detail Noise Strength", Float) = 0.01
		_DetailNoiseScale ("Detail Noise Scale", Float) = 30
	}
	
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	CBUFFER_START(UnityPerMaterial)
	float3 _ToonShadedColor;
	float3 _ToonLitColor;
	float _ToonColorSteps;
	float _ToonColorOffset;
	float _ToonColorSpread;
	float3 _ToonSpecularColor;
	float _ToonHighlightIntensity;
	float _DetailDensity;
	float2 _DetailScale;
	float _DetailNoiseStrength;
	float _DetailNoiseScale;
	CBUFFER_END
	ENDHLSL
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "AlphaTest" /*"RenderPipeline"="UniversalPipeline"*/ }
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
			
			#pragma multi_compile _ _DetailAlphaX_ON
			
			
			#define _AlphaClip 1
			#define _NORMALMAP 1
			// #define _SPECULAR_SETUP
			// #define _NORMAL_DROPOFF_TS 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			// #define ATTRIBUTES_NEED_TEXCOORD0
			// #define ATTRIBUTES_NEED_TEXCOORD1
			// #define VARYINGS_NEED_POSITION_WS
			// #define VARYINGS_NEED_NORMAL_WS
			// #define VARYINGS_NEED_TANGENT_WS
			// #define VARYINGS_NEED_TEXCOORD0
			// #define VARYINGS_NEED_VIEWDIRECTION_WS
			// #define VARYINGS_NEED_FOG_AND_VERTEX_LIGHT
			// #define FEATURES_GRAPH_VERTEX
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			#include "../CartoonCommon/MyCartoonPBR.hlsl"
			#include "MyCartoonWaterPBR.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				float4 normal: NORMAL;
				// float4 tangent: TANGENT;
				float2 uv: TEXCOORD0;
				float2 lightmapUV: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 normalWS: NORMAL;
				// float4 tangentWS: TANGENT;
				float3 positionWS: TEXCOORD0;
				float2 uv: TEXCOORD1;
				#if defined(LIGHTMAP_ON)
					float2 lightmapUV: TEXCOORD2;
				#endif
				float3 viewDirectionWS: TEXCOORD3;
				float4 screenUV: TEXCOORD4;
				float3 sh: TEXCOORD5;
				half4 fogFactorAndVertexLight: TEXCOORD6;
				float4 shadowCoord: TEXCOORD7;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.normalWS = TransformObjectToWorldNormal(v.normal.xyz, true);
				// o.tangentWS = float4(TransformObjectToWorldDir(v.tangent.xyz), v.tangent.w);
				o.positionCS = TransformWorldToHClip(o.positionWS);
				o.uv = v.uv;
				o.viewDirectionWS = GetWorldSpaceViewDir(o.positionWS);
				o.screenUV = ComputeScreenPos(o.positionCS, _ProjectionParams.x);
				
				//LightmapUV and SH
				OUTPUT_LIGHTMAP_UV(v.lightUV, unity_LightmapST, o.lightmapUV);
				//这里需要归一化normal 所以  在上面的Vertex归一化了
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
				i.viewDirectionWS = normalize(i.viewDirectionWS);
				float2 screenPosition = i.screenUV.xy / i.screenUV.w;
				
				MyInputData inputData = (MyInputData)0;
				inputData.positionWS = i.positionWS;
				inputData.normalWS = i.normalWS;
				inputData.viewDirectionWS = i.viewDirectionWS;
				inputData.shadowCoord = i.shadowCoord;
				inputData.fogCoord = i.fogFactorAndVertexLight.x;
				inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
				inputData.bakedGI = SAMPLE_GI(i.lightmapUV, i.sh, i.normalWS);
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS.xy);
				
				#if _AlphaClip
					float alphaClipThreshold = 0.5;
					#ifdef _DetailAlphaX_ON
						float alpha = DetailAlphaX(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#else
						float alpha = DetailAlphaY(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#endif
					clip(alpha - alphaClipThreshold);
				#else
					float alpha = 1;
				#endif
				
				float3 lightingColor = ToonLighting(i.positionWS, i.normalWS, i.viewDirectionWS, _ToonColorOffset, _ToonColorSpread, _ToonHighlightIntensity, _ToonColorSteps, _ToonShadedColor, _ToonLitColor, _ToonSpecularColor);
				float ao = AmbientOcclusion(screenPosition);
				
				MySurfaceData surfaceData = (MySurfaceData)0;
				surfaceData.albedo = IsGammaSpace() ? half3(0.0, 0.0, 0.0): SRGBToLinear(half3(0.0, 0.0, 0.0));
				surfaceData.specular = IsGammaSpace() ? half3(0.5, 0.5, 0.5): SRGBToLinear(half3(0.5, 0.5, 0.5));
				surfaceData.metallic = 0;
				surfaceData.smoothness = 0;
				surfaceData.normalTS = float3(0.0f, 0.0f, 1.0f);
				surfaceData.emission = lightingColor * ao;
				surfaceData.occlusion = 1;
				surfaceData.alpha = alpha;
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
			
			#pragma multi_compile _ _DetailAlphaX_ON
			
			
			#define _AlphaClip 1
			#define _NORMALMAP 1
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			#include "../CartoonCommon/MyCartoonPBR.hlsl"
			#include "MyCartoonWaterPBR.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				float4 normal: NORMAL;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float2 uv: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			
			
			// x: global clip space bias, y: normal world space bias
			float3 _LightDirection;
			
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
				float3 normalWS = TransformObjectToWorldNormal(v.normal.xyz, true);
				o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
				o.uv = v.uv;
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				#if _AlphaClip
					float alphaClipThreshold = 0.5;
					#ifdef _DetailAlphaX_ON
						float alpha = DetailAlphaX(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#else
						float alpha = DetailAlphaY(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#endif
					clip(alpha - alphaClipThreshold);
				#endif
				
				return 0;
			}
			ENDHLSL
			
		}
		
		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode" = "DepthOnly" }
			
			ColorMask 0
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			#pragma multi_compile _ _DetailAlphaX_ON
			
			
			#define _AlphaClip 1
			#define _NORMALMAP 1
			
			
			#include "../CartoonCommon/MyCartoonPBR.hlsl"
			#include "MyCartoonWaterPBR.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float2 uv: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.positionCS = TransformWorldToHClip(positionWS);
				o.uv = v.uv;
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				#if _AlphaClip
					float alphaClipThreshold = 0.5;
					#ifdef _DetailAlphaX_ON
						float alpha = DetailAlphaX(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#else
						float alpha = DetailAlphaY(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#endif
					clip(alpha - alphaClipThreshold);
				#endif
				
				return 0;
			}
			ENDHLSL
			
		}
		
		Pass
		{
			Name "DepthNormals"
			Tags { "LightMode" = "DepthNormals" }
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			#pragma multi_compile _ _DetailAlphaX_ON
			
			// Defines
			#define _AlphaClip 1
			#define _NORMALMAP 1
			// #define _NORMAL_DROPOFF_TS 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			
			#include "../CartoonCommon/MyCartoonPBR.hlsl"
			#include "MyCartoonWaterPBR.hlsl"
			
			struct a2v
			{
				float3 positionOS: POSITION;
				float3 normalOS: NORMAL;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 normalWS: NORMAL;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			v2f vert(a2v v)
			{
				v2f o = (v2f)0;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				float3 positionWS = TransformObjectToWorld(v.positionOS);
				o.normalWS = TransformObjectToWorldNormal(v.normalOS);
				o.positionCS = TransformWorldToHClip(positionWS);
				o.uv = v.uv;
				
				return o;
			}
			
			/*
			//Library\PackageCache\com.unity.render-pipelines.universal@10.0.0-preview.26\ShaderLibrary\ShaderVariablesFunctions.hlsl
			real3 NormalizeNormalPerPixel(real3 normalWS)
			{
				#if defined(SHADER_QUALITY_HIGH) || defined(_NORMALMAP)
					return normalize(normalWS);
				#else
					return normalWS;
				#endif
			}
			*/
			
			/*
			//Library\PackageCache\com.unity.render-pipelines.core@10.0.0-preview.30\ShaderLibrary\SpaceTransforms.hlsl
			real3 TransformWorldToViewDir(real3 dirWS, bool doNormalize = false)
			{
				float3 dirVS = mul((real3x3)GetWorldToViewMatrix(), dirWS).xyz;
				if (doNormalize)
					return normalize(dirVS);
				
				return dirVS;
			}
			*/
			
			/*
			//Library\PackageCache\com.unity.render-pipelines.core@10.0.0-preview.30\ShaderLibrary\Packing.hlsl
			real2 PackNormalOctRectEncode(real3 n)
			{
				// Perform planar projection.
				real3 p = n * rcp(dot(abs(n), 1.0));
				real  x = p.x, y = p.y, z = p.z;
				
				// Unfold the octahedron.
				// Also correct the aspect ratio from 2:1 to 1:1.
				real r = saturate(0.5 - 0.5 * x + 0.5 * y);
				real g = x + y;
				
				// Negative hemisphere on the left, positive on the right.
				return real2(CopySign(r, z), g);
			}
			
			real3 UnpackNormalOctRectEncode(real2 f)
			{
				real r = f.r, g = f.g;
				
				// Solve for {x, y, z} given {r, g}.
				real x = 0.5 + 0.5 * g - abs(r);
				real y = g - x;
				real z = max(1.0 - abs(x) - abs(y), REAL_EPS); // EPS is absolutely crucial for anisotropy
				
				real3 p = real3(x, y, CopySign(z, r));
				
				return normalize(p);
			}
			*/
			
			float4 frag(v2f i): SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				float3 normal = NormalizeNormalPerPixel(i.normalWS);
				
				#if _AlphaClip
					float alphaClipThreshold = 0.5;
					#ifdef _DetailAlphaX_ON
						float alpha = DetailAlphaX(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#else
						float alpha = DetailAlphaY(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#endif
					clip(alpha - alphaClipThreshold);
				#else
					float alpha = 1;
				#endif
				
				return float4(PackNormalOctRectEncode(TransformWorldToViewDir(normal, true)), 0.0, 0.0);
			}
			
			ENDHLSL
			
		}
		
		
		Pass
		{
			Name "Meta"
			Tags { "LightMode" = "Meta" }
			
			Cull Off
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			
			#pragma multi_compile _ _DetailAlphaX_ON
			
			
			#define _AlphaClip 1
			#define _NORMALMAP 1
			// #define _SPECULAR_SETUP
			// #define _NORMAL_DROPOFF_TS 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			// #define ATTRIBUTES_NEED_TEXCOORD0
			// #define ATTRIBUTES_NEED_TEXCOORD1
			// #define VARYINGS_NEED_POSITION_WS
			// #define VARYINGS_NEED_NORMAL_WS
			// #define VARYINGS_NEED_TANGENT_WS
			// #define VARYINGS_NEED_TEXCOORD0
			// #define VARYINGS_NEED_VIEWDIRECTION_WS
			// #define VARYINGS_NEED_FOG_AND_VERTEX_LIGHT
			// #define FEATURES_GRAPH_VERTEX
			
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
			
			#include "../CartoonCommon/MyCartoonPBR.hlsl"
			#include "MyCartoonWaterPBR.hlsl"
			
			struct a2v
			{
				float4 vertex: POSITION;
				float4 normal: NORMAL;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 normalWS: NORMAL;
				float3 positionWS: TEXCOORD0;
				float2 uv: TEXCOORD1;
				float3 viewDirectionWS: TEXCOORD2;
				float4 screenUV: TEXCOORD3;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.normalWS = TransformObjectToWorldNormal(v.normal.xyz, true);
				o.positionCS = TransformWorldToHClip(o.positionWS);
				o.uv = v.uv;
				o.viewDirectionWS = GetWorldSpaceViewDir(o.positionWS);
				o.screenUV = ComputeScreenPos(o.positionCS, _ProjectionParams.x);
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				i.normalWS = normalize(i.normalWS);
				i.viewDirectionWS = normalize(i.viewDirectionWS);
				float2 screenPosition = i.screenUV.xy / i.screenUV.w;
				
				
				#if _AlphaClip
					float alphaClipThreshold = 0.5;
					#ifdef _DetailAlphaX_ON
						float alpha = DetailAlphaX(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#else
						float alpha = DetailAlphaY(i.uv, _DetailScale, _DetailNoiseStrength, _DetailNoiseScale, _DetailDensity);
					#endif
					clip(alpha - alphaClipThreshold);
				#else
					float alpha = 1;
				#endif
				
				float3 lightingColor = ToonLighting(i.positionWS, i.normalWS, i.viewDirectionWS, _ToonColorOffset, _ToonColorSpread, _ToonHighlightIntensity, _ToonColorSteps, _ToonShadedColor, _ToonLitColor, _ToonSpecularColor);
				float ao = AmbientOcclusion(screenPosition);
				
				MetaInput input = (MetaInput)0;
				
				input.Albedo = IsGammaSpace() ? half3(0.0, 0.0, 0.0): SRGBToLinear(half3(0.0, 0.0, 0.0));
				input.Emission = lightingColor * ao;
				
				return MetaFragment(input);
			}
			ENDHLSL
			
		}
	}
}
