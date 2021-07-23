Shader "MyRP/ScreenEffect/S_KinoAqua"
{
	Properties
	{
		_NoiseTex("Noise Texture",2D)="grey"{}
		_Opacity("Opacity",Range(0, 1)) = 0.5
		_Interval("Interval",Range(0.1, 5.0)) = 1.25
		_Blur_Width("Blur Width",Range(0, 2.0)) = 1.35
		_Blur_Freq("Blur Freq",Range(0.0, 1.0)) = 0.5
		_Edge_Contrast("Edge Contrast",Range(0.01, 4.0)) = 1.2
		_Hue_Shift("Hue Shift",Range(0.0, 0.3)) = 0.1
		_EdgeColor("Edge Color", Color) = (0.15, 0.05, 0.05, 1)
		_FillColor("Fill Color", Color) = (0.8, 0.7, 0.6, 1)
		_Iteration("Iteration", Range(4, 32)) = 20
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Kino Aqua"
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
			TEXTURE2D(_NoiseTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _Opacity;
			float _Interval;
			float _Blur_Width;
			float _Blur_Freq;
			float _Edge_Contrast;
			float _Hue_Shift;
			float4 _EdgeColor;
			float4 _FillColor;
			uint _Iteration;


			float2 Rotate90(float2 v)
			{
				return v.yx * float2(-1, 1);
			}

			// Vertically normalized screen coordinates to UV
			float2 UV2SC(float2 uv)
			{
				float2 p = uv - 0.5;
				p.x *= _ScreenParams.x / _ScreenParams.y;
				return p;
			}

			float2 SC2UV(float2 p)
			{
				p.x *= _ScreenParams.y / _ScreenParams.x;
				return p + 0.5;
			}

			float3 SampleColor(float2 p)
			{
				float2 uv = SC2UV(p);
				return SAMPLE_TEXTURE2D_X(_SrcTex, s_linear_clamp_sampler, uv).rgb;
			}

			float SampleLuminance(float2 p)
			{
				return Luminance(SampleColor(p));
			}

			float3 SampleNoise(float2 p)
			{
				return SAMPLE_TEXTURE2D(_NoiseTex, s_linear_repeat_sampler, p).rgb;
			}

			float2 GetGradient(float2 p, float freq)
			{
				const float2 dx = float2(_Interval / 200, 0);
				float ldx = SampleLuminance(p + dx.xy) - SampleLuminance(p - dx.xy);
				float ldy = SampleLuminance(p + dx.yx) - SampleLuminance(p - dx.yx);
				float2 n = (SampleNoise(p * 0.4 * freq).gb - 0.5);
				return float2(ldx, ldy) + n * 0.05;
			}

			float ProcessEdge(inout float2 p, float stride)
			{
				float2 grad = GetGradient(p, 1);
				float edge = saturate(length(grad) * 10);
				float pattern = SampleNoise(p * 0.8).r;
				p += normalize(Rotate90(grad)) * stride;
				return pattern * edge;
			}

			float3 ProcessFill(inout float2 p, float stride)
			{
				float2 grad = GetGradient(p, _Blur_Freq);
				p += normalize(grad) * stride;
				float shift = SampleNoise(p * 0.1).r * 2;
				return SampleColor(p) * HsvToRgb(float3(shift, _Hue_Shift, 1));
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
				float2 p = UV2SC(IN.uv);

				float2 p_e_n = p;
				float2 p_e_p = p;
				float2 p_c_n = p;
				float2 p_c_p = p;

				const float Stride = 0.04 / _Iteration;
				const float InvIter = 1 / _Iteration;

				float acc_e = 0;
				float3 acc_c = 0;
				float sum_e = 1e-6; //避免0
				float sum_c = 1e-6; //避免0

				for (uint i = 0; i < _Iteration; i++)
				{
					float a = (float)i * InvIter;
					float w_e = 1.5 - a;
					acc_e += ProcessEdge(p_e_n, -Stride) * w_e;
					acc_e += ProcessEdge(p_e_p, +Stride) * w_e;
					sum_e += w_e * 2;

					float w_c = 0.2 + a;
					acc_c += ProcessFill(p_c_n, -Stride * _Blur_Width) * w_c;
					acc_c += ProcessFill(p_c_p, +Stride * _Blur_Width) * w_c * 0.3;
					sum_c += w_c * 1.3;
				}

				//normalize and contrast
				acc_e /= sum_e;
				acc_c /= sum_c;

				acc_e = saturate((acc_e - 0.5) * _Edge_Contrast + 0.5);

				//color blending

				float3 rgb_e = lerp(1, _EdgeColor.rgb, _EdgeColor.a * acc_e);
				float3 rgb_f = lerp(1, acc_c, _FillColor.a) * _FillColor.rgb;

				//_ScreenSize is in deferred
				uint2 positionSS = IN.uv * _ScreenParams.xy;
				half4 src = LOAD_TEXTURE2D_X(_SrcTex, positionSS);

				return half4(lerp(src.rgb, rgb_e * rgb_f, _Opacity), src.a);
			}
			ENDHLSL
		}
	}
}