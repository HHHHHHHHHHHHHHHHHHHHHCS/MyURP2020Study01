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
			"RenderType" = "Opaque" "Queue" = "Geometry" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		SAMPLER(sampler_MainTex);
		float4 _MainTex_ST;

		half3 _Color;

		half3 _ShadowColor;
		half _ShadowThreshold;
		half3 _SpecularColor;
		half _SpecularPower;
		half _SpecularThreshold;

		float _OutlineWidth;
		half3 _OutlineColor;
		CBUFFER_END

		TEXTURE2D(_MainTex);
		
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

				//ambient lighting
				half3 ambient = max(SampleSH(half3(0, 1, 0)), SampleSH(half3(0, -1, 0)));

				//diffuse lighting
				half nl = dot(normalDir, lightDir);
				half3 diff = nl > _ShadowThreshold ? 1.0 : _ShadowColor;

				//specular lighting
				half nh = dot(normalDir, halfDir);
				half3 spec = pow(max(nh, 1e-5), _SpecularPower) > _SpecularThreshold ? _SpecularColor : 0.0;

				half3 col = ambient * albedo + (diff + spec) * albedo * _MainLightColor.rgb;

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