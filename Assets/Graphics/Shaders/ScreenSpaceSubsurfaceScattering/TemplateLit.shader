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
				float2 uv : TEXCOORD0;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

				#ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
				float3 positionWS : TEXCOORD2;
				#endif

				float3 normalWS : TEXCOORD3;
				#ifdef _NORMALMAP
			    float4 tangentWS : TEXCOORD4;// xyz:tangent, w:sign
				#endif

				float3 viewDirWS : TEXCOORD5;

				half4 fogFactorAndVertexLight : TEXCOORD6; // x:fogFactor, yzw: vertex light

				#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
			    float4 shadowCoord : TEXCOORD7;
				#endif

				float4 positionCS : SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
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

			v2f vert(a2v IN)
			{
				v2f o = (v2f)0;

				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_TRANSFER_INSTANCE_ID(IN, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.positionWS = TransformObjectToWorld(IN.positionOS);
				o.uv = TRANSFORM_TEX(o.uv, _MainTex);

				GetVertexNormalInputs()

					OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
				OUTPUT_SH(o.normalWS.xyz, o.vertexSH);
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