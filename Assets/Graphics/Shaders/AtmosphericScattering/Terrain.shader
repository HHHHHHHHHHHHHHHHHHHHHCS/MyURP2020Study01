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

			#pragma multi_compile _ _LIGHT_SHAFT


			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
			// #include "ShaderLibrary/AerialPerspective.hlsl"

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

				//#if SHADER_HINT_NICE_QUALITY
				worldViewDirection = SafeNormalize(worldViewDirection);
				//#endif

				float2 uv = IN.uv.xy;

				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_linear_clamp, uv).rgb;

				return half4(albedo, 1.0);
			}
			ENDHLSL
		}
	}
}