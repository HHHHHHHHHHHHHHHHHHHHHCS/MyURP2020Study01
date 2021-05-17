Shader "MyRP/UnityChanSSU/1_BasicToon_Final"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white"{}
		_Color("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_ShadowColor("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
		_ShadowThreshold("Shadow Threshold", Range(-1.0, 1.0)) = 0.0
		[HDR] _SpecularColor("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_SpecularPower("Specular Power", Float) = 20.0
		_SpecularThreshold("Specular Threshold", Range(0.0, 1.0)) = 0.5

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
		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);
		float4 _MainTex_ST;

		half4 _Color;

		half4 _ShadowColor;
		half _ShadowThreshold;
		half4 _SpecularColor;
		half _SpecularPower;
		half _SpecularThreshold;

		float _OutlineWidth;
		half4 _OutlineColor;
		CBUFFER_END
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
				o.worldPos = TransformObjectToWorld(v.vertex);
				o.vertex = TransformWorldToHClip(o.worldPos);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normalDir = TransformObjectToWorldNormal(v.normal);
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half3 normalDir = normalize(IN.normalDir);
				half3 lightDir = normalize(_MainLightPosition.xyz);
				half3 viewDir = normalize(GetWorldSpaceViewDir(IN.worldPos));
				half3 halfDir = normalize(lightDir + viewDir);

				half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color.rgb;

				//ambient lighting
				half3 ambient = max(SampleSH(half3(0, 1, 0)), SampleSH(half3(0, -1, 0)));

				//diffuse lighting
				half nl = dot(normalDir, lightDir);
				half3 diff = nl > _ShadowThreshold ? 1.0 : _ShadowColor.rgb;

				//specular lighting
				half nh = dot(normalDir, halfDir);
				half3 spec = pow(max(nh, 1e-5), _SpecularPower) > _SpecularThreshold ? _SpecularColor : 0.0;

				half3 col = ambient * albedo.rgb + (diff + spec) * albedo.rgb * _MainLightColor.rgb;

				return half4(col.rgb, 1.0);
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

				half3 col = albedo * _OutlineColor.rgb;

				return half4(col, 1.0);
				
			}
			ENDHLSL
		}
	}
}