Shader "MyRP/AtmosphericScattering/Terrain"
{
	Properties
	{
		[NoScaleOffset]_MainTex("_MainTex", 2D) = "white" {}
		[NoScaleOffset]_BumpMap("_BumpMap", 2D) = "white" {}
		[NoScaleOffset]_BumpMap2("_BumpMap2", 2D) = "white" {}
		_Bump1Scale("_Bump1Scale", Range( -1 , 1)) = 1
		_Bump2Scale("_Bump2Scale", Range( -1 , 1)) = 0.5
		[NoScaleOffset]_Occlusion("_Occlusion", 2D) = "black" {}
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalPipeline"
		}

		Pass
		{
			Name "Forward"
			Tags
			{
				"LightMode"="UniversalForward"
			}

			HLSLPROGRAM
			// #pragma prefer_hlslcc gles
			// #pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#define _NORMALMAP 1

			#pragma multi_compile_instancing

			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON

			// #pragma multi_compile _ _AERIAL_PERSPECTIVE
			#define _AERIAL_PERSPECTIVE 1
			#pragma multi_compile _ _LIGHT_SHAFT


			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "AerialPerspective.hlsl"

			TEXTURE2D(_MainTex);
			TEXTURE2D(_BumpMap);
			TEXTURE2D(_BumpMap2);
			TEXTURE2D(_Occlusion);
			SAMPLER(sampler_linear_clamp);

			CBUFFER_START(UnityPerMaterial)
			float _Bump1Scale;
			float _Bump2Scale;
			CBUFFER_END

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord0 : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 clipPos : SV_POSITION;
				float4 lightmapUVOrVertexSH : TEXCOORD0;
				half4 fogFactorAndVertexLight : TEXCOORD1;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				float4 shadowCoord : TEXCOORD2;
				#endif
				float4 tSpace0 : TEXCOORD3;
				float4 tSpace1 : TEXCOORD4;
				float4 tSpace2 : TEXCOORD5;
				float4 uv : TEXCOORD6;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert(a2v IN)
			{
				v2f o = (v2f)0;

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv.xy = IN.texcoord0.xy;
				o.uv.zw = 0;

				float3 positionWS = TransformObjectToWorld(IN.vertex.xyz);
				float4 positionCS = TransformWorldToHClip(positionWS);

				VertexNormalInputs tbn = GetVertexNormalInputs(IN.normal, IN.tangent);

				o.tSpace0 = float4(tbn.tangentWS, positionWS.x);
				o.tSpace1 = float4(tbn.bitangentWS, positionWS.y);
				o.tSpace2 = float4(tbn.normalWS, positionWS.z);

				OUTPUT_LIGHTMAP_UV(IN.texcoord1, unity_LightmapST, o.lightmapUVOrVertexSH.xy);
				OUTPUT_SH(tbn.normalWS.xyz, o.lightmapUVOrVertexSH.xyz);

				o.fogFactorAndVertexLight.x = ComputeFogFactor(positionCS.z);
				o.fogFactorAndVertexLight.yzw = VertexLighting(positionWS, tbn.normalWS.xyz);

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				o.shadowCoord = TransformWorldToShadowCoord(positionWS);
				#endif


				o.clipPos = positionCS;
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

				float3 worldTangent = normalize(IN.tSpace0.xyz);
				float3 worldBitangent = normalize(IN.tSpace1.xyz);
				float3 worldNormal = normalize(IN.tSpace2.xyz);
				float3 worldPosition = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
				float3 worldViewDirection = GetWorldSpaceViewDir(worldPosition);
				float4 shadowCoords = float4(0, 0, 0, 0);

				#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
					shadowCoords = IN.shadowCoord;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					shadowCoords = TransformWorldToShadowCoord(worldPosition);
				#endif

				#if SHADER_HINT_NICE_QUALITY
				worldViewDirection = SafeNormalize(worldViewDirection);
				#endif

				float2 uv = IN.uv.xy;

				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_linear_clamp, uv).rgb;
				real3 normalA = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_linear_clamp, uv), _Bump1Scale);
				real3 normalB = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap2, sampler_linear_clamp, uv), _Bump2Scale);
				float3 normal = BlendNormal(normalA, normalB);
				float3 emission = 0;
				float3 specular = 0.5;
				float metallic = 0;
				float smoothness = 0.5;
				float occlusion = SAMPLE_TEXTURE2D(_Occlusion, sampler_linear_clamp, uv).r;
				float alpha = 1;

				InputData inputData;
				inputData.positionWS = worldPosition;
				inputData.viewDirectionWS = worldViewDirection;
				inputData.shadowCoord = shadowCoords;

				#ifdef _NORMALMAP
				inputData.normalWS = normalize(
					TransformTangentToWorld(normal, half3x3(worldTangent, worldBitangent, worldNormal)));
				#else
				#if !SHADER_HINT_NICE_QUALITY
					inputData.normalWS = WorldNormal;
				#else
					inputData.normalWS = normalize( WorldNormal );
				#endif
				#endif

				inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
				inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, IN.lightmapUVOrVertexSH.xyz,
				                              inputData.normalWS);
				half4 color = UniversalFragmentPBR(
					inputData,
					albedo,
					metallic,
					specular,
					smoothness,
					occlusion,
					emission,
					alpha);

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition(IN.clipPos.xyz, unity_LODFade.x);
				#endif

				APPLY_SCATTERING(color, inputData.positionWS, IN.clipPos.xy / _ScreenParams.xy);

				return half4(color);
			}
			ENDHLSL
		}

		Pass
		{
			Name "ShadowCaster"
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			ColorMask 0

			HLSLPROGRAM
			// #pragma prefer_hlslcc gles
			// #pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_instancing
			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			float3 _LightDirection;

			struct a2v
			{
				float4 vertex:POSITION;
				float3 normal:NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 clipPos :SV_POSITION;
			};

			v2f vert(a2v IN)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 positionWS = TransformObjectToWorld(IN.vertex.xyz);
				float3 normalWS = TransformObjectToWorldDir(IN.normal);
				float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

				#if UNITY_REVERSED_Z
				clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
				#else
				clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
				#endif

				o.clipPos = clipPos;

				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				return 0;
			}
			ENDHLSL
		}

		Pass
		{

			Name "DepthOnly"
			Tags
			{
				"LightMode"="DepthOnly"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_instancing
			#pragma multi_compile _ LOD_FADE_CROSSFADE

			// #pragma prefer_hlslcc gles
			// #pragma exclude_renderers d3d11_9x

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				float4 vertex : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 clipPos : SV_POSITION;
			};


			v2f vert(a2v v)
			{
				v2f o = (v2f)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.clipPos = TransformObjectToHClip(v.vertex.xyz);
				return o;
			}

			half4 frag(v2f IN) : SV_TARGET
			{
				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif
				return 0;
			}
			ENDHLSL
		}


		Pass
		{

			Name "Meta"
			Tags
			{
				"LightMode"="Meta"
			}

			Cull Off

			HLSLPROGRAM
			// #pragma prefer_hlslcc gles
			// #pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);

			// #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv0 : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				float2 uv2 : TEXCOORD2;
			};

			struct v2f
			{
				float4 clipPos : SV_POSITION;
				float2 uv0:TEXCOORD0;
			};


			v2f vert(a2v IN)
			{
				v2f o = (v2f)0;

				o.clipPos = MetaVertexPosition(IN.vertex, IN.uv1.xy, IN.uv2.xy, unity_LightmapST,
				                               unity_DynamicLightmapST);
				o.uv0 = IN.uv0;

				return o;
			}

			half4 frag(v2f IN) : SV_TARGET
			{
				float3 Albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv0).rgb;
				float3 Emission = 0;

				MetaInput metaInput = (MetaInput)0;
				metaInput.Albedo = Albedo;
				metaInput.Emission = Emission;

				return MetaFragment(metaInput);
			}
			ENDHLSL
		}
	}
}