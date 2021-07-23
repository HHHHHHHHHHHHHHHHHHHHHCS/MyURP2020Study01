Shader "MyRP/ScreenEffect/S_OilPaint"
{
	Properties
	{
		_Radius("_Radius",Range(0.0,5.0)) = 2.0
		_ResolutionValue("_ResolutionValue",Range(0.0,5.0)) = 1.0
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Oil Paint"
			ZTest Always
			ZWrite Off
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				uint vertexID :SV_VertexID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			TEXTURE2D_X(_SrcTex);
			SAMPLER(sampler_SrcTex);
			float4 _SrcTex_TexelSize;

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _Radius;
			float _ResolutionValue;


			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
				float2 srcSize = _ResolutionValue * _SrcTex_TexelSize.xy;
				float2 uv = IN.uv;
				float n = _Radius + 1;
				n *= n;

				float3 m0 = 0;
				float3 s0 = 0;
				float3 m1 = 0;
				float3 s1 = 0;
				float3 m2 = 0;
				float3 s2 = 0;
				float3 m3 = 0;
				float3 s3 = 0;

				half3 color = 0;
				int j, k;
				for (j = -_Radius; j <= 0; ++j)
				{
					for (k = -_Radius; k <= 0; ++k)
					{
						color = SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, uv+float2(k,j)*srcSize).rgb;
						m0 += color;
						s0 += color * color;
					}
				}


				for (j = -_Radius; j <= 0; ++j)
				{
					for (k = 0; k <= _Radius; ++k)
					{
						color = SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, uv+float2(k,j)*srcSize).rgb;
						m1 += color;
						s1 += color * color;
					}
				}

				for (j = 0; j <= _Radius; ++j)
				{
					for (k = 0; k <= _Radius; ++k)
					{
						color = SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, uv+float2(k,j)*srcSize).rgb;
						m2 += color;
						s2 += color * color;
					}
				}

				for (j = 0; j <= _Radius; ++j)
				{
					for (k = -_Radius; k <= 0; ++k)
					{
						color = SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, uv+float2(k,j)*srcSize).rgb;
						m3 += color;
						s3 += color * color;
					}
				}

				float min_sigma2 = 0;
				half4 finalColor;
				finalColor.a = 1;

				m0 /= n;
				s0 = abs(s0 / n - m0 * m0);
				float sigma2 = s0.r + s0.g + s0.b;
				min_sigma2 = sigma2;
				finalColor.rgb = m0;

				m1 /= n;
				s1 = abs(s1 / n - m1 * m1);
				sigma2 = s1.r + s1.g + s1.b;
				if (sigma2 < min_sigma2)
				{
					min_sigma2 = sigma2;
					finalColor.rgb = m1;
				}

				m2 /= n;
				s2 = abs(s2 / n - m2 * m2);
				sigma2 = s2.r + s2.g + s2.b;
				if (sigma2 < min_sigma2)
				{
					min_sigma2 = sigma2;
					finalColor.rgb = m2;
				}


				m3 /= n;
				s3 = abs(s3 / n - m3 * m3);
				sigma2 = s3.r + s3.g + s3.b;
				if (sigma2 < min_sigma2)
				{
					min_sigma2 = sigma2;
					finalColor.rgb = m3;
				}

				return finalColor;
			}
			ENDHLSL
		}
	}
}