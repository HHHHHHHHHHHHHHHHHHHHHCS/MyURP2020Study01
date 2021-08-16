Shader "MyRP/ScreenEffect/S_SketchDrawing"
{
	Properties
	{
		_NoiseTex("Noise Texture", 2D) = "grey"{}
		_AngleNum("Angle Number", Range(0, 10)) = 4
		_Range("Range",Range(0,64)) = 16
		_Step("Step",Range(1,10)) = 2
		[Toggle(_IsGray)] _IsGray ("Is Gray", int) = 0
		[Toggle(_IsGroup1)] _IsGroup1 ("Is Group1", int) = 0
	}

	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		ZTest Always
		ZWrite Off
		Cull Off

		Pass
		{
			Name "Sketch Drawing"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

			#pragma shader_feature _IsGray
			#pragma shader_feature _IsGroup1


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

			//0.01的阀值感觉效果还行
			#define MAGIC_GRAD_THRESH 0.01

			#if _IsGroup1
			// Setting group 1:   效果比较黑白
			#define MAGIC_SENSITIVITY     4.
			#define MAGIC_COLOR           1.
			#else
				// Setting group 2:    效果比较彩色
				#define MAGIC_SENSITIVITY     10.
				#define MAGIC_COLOR           0.5
			#endif


			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_point_clamp_sampler);
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			TEXTURE2D(_SrcTex);
			TEXTURE2D(_NoiseTex);

			float _AngleNum;
			float _Range;
			float _Step;

			inline half4 SampleSrcTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
			}

			inline half4 SampleNoiseTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_NoiseTex, s_linear_repeat_sampler, uv);
			}

			half4 GetCol(float2 pos)
			{
				float2 uv = pos / _ScreenParams.xy;
				return SampleSrcTex(uv);
			}

			float GetVal(float2 pos)
			{
				half4 c = GetCol(pos);
				return Luminance(c);
			}

			float2 GetGrad(float2 pos, float eps)
			{
				float2 d = float2(eps, 0);
				return float2(
					GetVal(pos + d.xy) - GetVal(pos - d.xy),
					GetVal(pos + d.yx) - GetVal(pos - d.yx)
				) / eps / 2.;
			}

			void PointRot(inout float2 p, float a)
			{
				p = cos(a) * p + sin(a) * float2(p.y, -p.x);
			}

			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;
				float2 pos = uv * _ScreenParams.xy;

				float weight = 1.0;
				float divNum = floor((2.0 * _Range + 1.0) / _Step) * _AngleNum;

				UNITY_LOOP
				for (float j = 0.0; j < _AngleNum; j += 1.0)
				{
					float2 dir = float2(1, 0);
					PointRot(dir, j * PI / _AngleNum);

					float2 grad = float2(-dir.y, dir.x);

					UNITY_LOOP
					for (float i = -_Range; i <= _Range; i += _Step)
					{
						float2 pos2 = pos + normalize(dir) * i;

						if (pos2.x < 0 || pos2.y < 0 || pos2.x > _ScreenParams.x || pos2.y > _ScreenParams.y)
						{
							continue;
						}

						float2 g = GetGrad(pos2, 1.0);

						if (length(g) < MAGIC_GRAD_THRESH)
						{
							continue;
						}

						float w = pow(abs(dot(normalize(grad), normalize(g))),MAGIC_SENSITIVITY);
						weight -= w / divNum;
					}
				}

				#ifndef _IsGray
				    float4 col = GetCol(pos);
				#else
				float4 col = GetVal(pos);
				#endif

				float4 background = lerp(col, 1,MAGIC_COLOR);

				float r = length(pos - _ScreenParams.xy * 0.5) / _ScreenParams.x;
				float vign = 1.0 - r * r * r;

				half4 noise = SampleNoiseTex(IN.uv);

				half4 color = vign * lerp(0, background, weight) + noise / 25.0;

				return color;
			}
			ENDHLSL
		}
	}
}