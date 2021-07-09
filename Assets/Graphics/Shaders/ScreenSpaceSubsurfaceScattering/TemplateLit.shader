//Todo:暂时先不做 需要延迟渲染
Shader "MyRP/ScreenSpaceSubsurfaceScattering/TemplateLit"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[NoScaleOffset]_MetallicGlossMap ("Metallic (R), Smoothness (A)", 2D) = "white" {}
		[NoScaleOffset]_BumpMap ("Normal (RGB)", 2D) = "bump" {}
		[NoScaleOffset]_OcclusionMap ("Occlusion (G)", 2D) = "white" {}

		[Header(Sub Surface Scattering)]
		[NoScaleOffset]_SSSTex("SSS Color (RGB), SSS Radius (A)", 2D) = "white" {}
		_SSSColor("Color", Color) = (1.0, 0.3, 0.3,1)
		_SSSRadius ("Radius", Range(0.0, 1.0)) = 0.5

		[Header(Transmittance)]
		[NoScaleOffset]_TransmittanceTex ("Thickness", 2D) = "white" {}
		_TransmittanceExp ("Exponent", Range(1.0, 8.0)) = 1.0
		_Transmittance ("Scale", Range(0.0, 1.0)) = 1.0
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector"="True"
		}

		Pass
		{
			Name "SSSSLit"
			Tags
			{
				"LightMode" = "SSSSLit"
			}

			Blend One Zero
			ZWrite On
			Cull Back

			HLSLPROGRAM
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			#include "SSSSPBSLighting.hlsl"

			struct a2v
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float2 texcoord : TEXCOORD0;
				float2 lightmapUV : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 TBN0 : TEXCOORD1;
				float4 TBN1 : TEXCOORD2;
				float4 TBN2 : TEXCOORD3;
				float4 screenPos : TEXCOORD4;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);

				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct Input
			{
				float2 uv_MainTex;
				float4 screenPos;
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _MainTex_ST;
			half4 _Color;
			half _Glossiness;
			half _Metallic;

			half4 _SSSColor;
			half _SSSRadius;
			half _Transmittance;
			half _TransmittanceExp;
			CBUFFER_END

			TEXTURE2D(_MainTex); // RGB = Diffuse or specular color
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_BumpMap); // RGB = Normal
			SAMPLER(sampler_BumpMap);
			TEXTURE2D(_MetallicGlossMap); // R = Metallic, A = Smoothness
			SAMPLER(sampler_MetallicGlossMap);
			TEXTURE2D(_OcclusionMap); // G = Occlusion
			SAMPLER(sampler_OcclusionMap);
			// SSS
			TEXTURE2D(_SSSTex); // RGB = SSS color, A = SSS radius
			SAMPLER(sampler_SSSTex);
			TEXTURE2D(_TransmittanceTex); // B = Transmittance
			SAMPLER(sampler_TransmittanceTex);


			void surf(Input IN, inout SurfaceOutputStandardSSSS o)
			{
				o = (SurfaceOutputStandardSSSS)0;
			}

			v2f vert(a2v IN)
			{
				v2f o = (v2f)0;

				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_TRANSFER_INSTANCE_ID(IN, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float3 positionWS = TransformObjectToWorld(IN.positionOS);
				o.pos = TransformWorldToHClip(positionWS);
				o.uv = TRANSFORM_TEX(IN.texcoord, _MainTex);

				VertexNormalInputs tbn = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
				o.TBN0 = float4(tbn.tangentWS.x, tbn.bitangentWS.x, tbn.normalWS.x, positionWS.x);
				o.TBN1 = float4(tbn.tangentWS.y, tbn.bitangentWS.y, tbn.normalWS.y, positionWS.y);
				o.TBN2 = float4(tbn.tangentWS.z, tbn.bitangentWS.z, tbn.normalWS.z, positionWS.z);
				o.screenPos = ComputeScreenPos(o.pos);

				OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, o.lightmapUV);
				OUTPUT_SH(tbn.normalWS.xyz, o.vertexSH);

				return o;
			}

			void frag(v2f IN,
			          out half4 outGBuffer0 : SV_Target0,
			          out half4 outGBuffer1 : SV_Target1,
			          out half4 outGBuffer2 : SV_Target2,
			          out half4 outGBuffer3 : SV_Target3)
			{
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

				Input input;
				input.uv_MainTex = IN.uv;
				input.screenPos = IN.screenPos;


				SurfaceOutputStandardSSSS o;
				surf(input, o);

				float3 worldN;
				worldN.x = dot(IN.TBN0.xyz, o.Normal);
				worldN.y = dot(IN.TBN1.xyz, o.Normal);
				worldN.z = dot(IN.TBN2.xyz, o.Normal);
				worldN = normalize(worldN);
				o.Normal = worldN;

				// UnityGIInput giInput;
				outGBuffer0 = 0;
				outGBuffer1 = 0;
				outGBuffer2 = 0;
				outGBuffer3 = 0;
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

			ZWrite On
			ZTest LEqual
			Cull[_Cull]

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature _ALPHATEST_ON

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags
			{
				"LightMode" = "DepthOnly"
			}

			ZWrite On
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			ENDHLSL
		}

		// This pass it not used during regular rendering, only for lightmap baking.
		Pass
		{
			Name "Meta"
			Tags
			{
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x

			#pragma vertex UniversalVertexMeta
			#pragma fragment UniversalFragmentMeta

			#pragma shader_feature _SPECULAR_SETUP
			#pragma shader_feature _EMISSION
			#pragma shader_feature _METALLICSPECGLOSSMAP
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			#pragma shader_feature _SPECGLOSSMAP

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "Universal2D"
			Tags
			{
				"LightMode" = "Universal2D"
			}

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _ALPHAPREMULTIPLY_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
			ENDHLSL
		}
	}
}