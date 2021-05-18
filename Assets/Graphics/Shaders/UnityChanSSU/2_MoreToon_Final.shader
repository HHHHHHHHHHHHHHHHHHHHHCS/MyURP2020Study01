Shader "MyRP/UnityChanSSU/2_MoreToon_Final"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_GradientMap ("Gradient Map", 2D) = "white" {}

		_ShadowColor1stTex ("1st Shadow Color Tex", 2D) = "white" {}
		_ShadowColor1st ("1st Shadow Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_ShadowColor2ndTex ("2nd Shadow Color Tex", 2D) = "white" {}
		_ShadowColor2nd ("2nd Shadow Color", Color) = (1.0, 1.0, 1.0, 1.0)

		[HDR] _SpecularColor ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_SpecularPower ("Specular Power", Float) = 20.0

		_RimLightMask ("Rim Light Mask", 2D) = "white" {}
		[HDR] _RimLightColor ("Rim Light Color", Color) = (0.0, 0.0, 0.0, 1.0)
		_RimLightPower ("Rim Light Power", Float) = 20.0

		_OutlineWidth ("Outline Width", Range(0.0, 3.0)) = 1.0
		_OutlineColor ("Outline Color", Color) = (0.2, 0.2, 0.2, 1.0)
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _MainTex_ST;

		half3 _Color;

		half3 _ShadowColor1st;
		half3 _ShadowColor2nd;

		half3 _SpecularColor;
		half _SpecularPower;
		half _SpecularThreshold;

		half3 _RimLightColor;
		half _RimLightPower;

		float _OutlineWidth;
		half3 _OutlineColor;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		TEXTURE2D(_GradientMap);
		SAMPLER(sampler_GradientMap);
		TEXTURE2D(_ShadowColor1stTex);
		SAMPLER(sampler_ShadowColor1stTex);
		TEXTURE2D(_ShadowColor2ndTex);
		SAMPLER(sampler_ShadowColor2ndTex);
		TEXTURE2D(_RimLightMask);
		SAMPLER(sampler_RimLightMask);
		ENDHLSL

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.worldPos = TransformObjectToWorld(v.vertex.xyz);
				o.vertex = TransformWorldToHClip(o.worldPos);
				o.normalDir = TransformObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half3 normalDir = normalize(IN.normalDir);
				half3 lightDir = normalize(_MainLightPosition.xyz);
				half3 viewDir = normalize(GetWorldSpaceViewDir(IN.worldPos));
				half3 halfDir = normalize(lightDir + viewDir);

				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb * _Color;

				//Ambient Lighting
				half3 ambient = max(SampleSH(half3(0.0, 1.0, 0.0)), SampleSH(half3(0.0, -1.0, 0.0)));

				//Diffuse Lighting
				half nl = dot(normalDir, lightDir) * 0.5 + 0.5;
				half2 diffGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap, float2(nl, 0.5)).rg;
				half3 diffAlbedo = lerp(
					albedo,
					SAMPLE_TEXTURE2D(_ShadowColor1stTex, sampler_ShadowColor1stTex, IN.uv).rgb * _ShadowColor1st,
					diffGradient.x);
				diffAlbedo = lerp(
					diffAlbedo,
					SAMPLE_TEXTURE2D(_ShadowColor2ndTex, sampler_ShadowColor2ndTex, IN.uv).rgb * _ShadowColor2nd,
					diffGradient.y);
				half3 diff = diffAlbedo;

				//Specular Lighting
				half nh = dot(normalDir, halfDir);
				half specGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap,
				                                     float2(pow(max(nh, 1e-5), _SpecularPower), 0.5)).b;
				half3 spec = specGradient * albedo * _SpecularColor;

				//Rim Lighting
				half nv = dot(normalDir, viewDir);
				half rimLightGradient = SAMPLE_TEXTURE2D(_GradientMap, sampler_GradientMap,
				                                         float2(pow(max(1.0 - clamp(nv, 0.0, 1.0), 1e-5), _RimLightPower
				                                         ), 0.5)).a;
				half rimLightMask = SAMPLE_TEXTURE2D(_RimLightMask, sampler_RimLightMask, IN.uv).r;
				half3 rimLight = (rimLightGradient * rimLightMask) * _RimLightColor  * diff;

				half3 col = ambient * albedo + (diff + spec) * _MainLightColor.rgb + rimLight;
				
				return half4(col, 1.0);
			}
			ENDHLSL
		}

		Pass
		{
			Name "Outline"
			Tags
			{
				"LightMode" = "Outline"
			}

			Cull Front

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(a2v v)
			{
				v2f o;

				//UNITY_MATRIX_MV == mul(UNITY_MATRIX_V, UNITY_MATRIX_M)
				float3 viewPos = mul(UNITY_MATRIX_MV, v.vertex).xyz;
				float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
				viewNormal.z = -0.5;
				viewPos += normalize(viewNormal) * _OutlineWidth * 0.002;

				o.vertex = TransformWViewToHClip(viewPos);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb * _Color.rgb;

				half3 col = albedo * _OutlineColor;

				return half4(col, 1.0);
			}
			ENDHLSL
		}
	}
}