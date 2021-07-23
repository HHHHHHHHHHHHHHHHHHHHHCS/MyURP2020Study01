Shader "MyRP/UnityChanSSU/5_Animation_Final"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		[HDR] _Color ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_ColorGradient ("Color Gradient", 2D) = "white" {}
		_ColorGradientTiling ("Color Gradient Tiling", Float) = 1.0
		_ColorGradientSpeed ("Color Gradient Speed", Float) = 1.0
		_AlphaGradient ("Alpha Gradient", 2D) = "white" {}
		_AlphaGradientTiling ("Alpha Gradient Tiling", Float) = 1.0
		_AlphaGradientSpeed ("Alpha Gradient Speed", Float) = 1.0
		_GridSize ("Grid Size", Range(0.0, 1.0)) = 0.1
		_SpotSize ("Spot Size", Range(0.0, 0.5)) = 0.3
	}
	SubShader
	{
		Tags
		{
			"Queue" = "Transparent" "RenderType" = "Transparent" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			Cull Back
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			CBUFFER_START(UnityPerMaterial)
			float4 _MainTex_ST;
			half4 _Color;

			float _ColorGradientTiling;
			float _ColorGradientSpeed;
			float _AlphaGradientTiling;
			float _AlphaGradientSpeed;

			half _GridSize;
			half _SpotSize;
			CBUFFER_END

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D(_ColorGradient);
			SAMPLER(sampler_ColorGradient);
			TEXTURE2D(_AlphaGradient);
			SAMPLER(sampler_AlphaGradient);

			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;
				half3 col = albedo.rgb;
				half alpha = albedo.a;

				float distToCenter = length(IN.uv - 0.5);

				float colorGradientSample = distToCenter * _ColorGradientTiling + _Time.y * _ColorGradientSpeed;
				half3 colorGradient = SAMPLE_TEXTURE2D(_ColorGradient, sampler_ColorGradient,
				                                       float2(colorGradientSample, 0.5)).rgb;
				col *= colorGradient;

				float alphaGradientSample = distToCenter * _AlphaGradientTiling + _Time.y * _AlphaGradientSpeed;
				half alphaGradient = SAMPLE_TEXTURE2D(_AlphaGradient, sampler_AlphaGradient,
				                                      float2(alphaGradientSample, 0.5)).r;
				alpha *= alphaGradient;

				half2 grid = fmod(IN.uv, _GridSize) / _GridSize;
				half distToGrid = length(grid - 0.5);
				alpha *= step(distToGrid, _SpotSize);

				return half4(col, alpha);
			}
			ENDHLSL
		}
	}
}