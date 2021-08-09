Shader "MyRP/ScreenEffect/S_GlitchJitter"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl", Range(0, 1)) = 0.5
		//FilmGrain
		_GrainTex("Grain Texture",2D) = "grey"{}

		//Jitter
		_Frequency("Frequency",Range(0,50.0)) = 20
		_RGBSplit("RGBSplit", Range(0, 500.0)) = 20
		_Speed("Speed", Range(0, 1.0)) = 0.25
		_Amount("Amount", Range(0, 2.0)) = 1

		//dark
		_Dark("Dark", Range(0, 2.0)) = 0.5

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
			Name "Glitch Shake"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

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

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_point_clamp_sampler);
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			TEXTURE2D(_SrcTex);

			float _ProgressCtrl;

			TEXTURE2D(_GrainTex);
			SAMPLER(sampler_GrainTex);

			float _Frequency;
			float _RGBSplit;
			float _Speed;
			float _Amount;

			float _Dark;

			#define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744f

			inline half4 SampleSrcTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
			}

			//Random
			//----------------------

			float2 Mod289(float2 x)
			{
				return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
			}

			float3 Mod289(float3 x)
			{
				return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
			}

			float3 Permute(float3 x)
			{
				return Mod289(x * x * 34.0 + x);
			}

			float3 TaylorInvSqrt(float3 r)
			{
				return 1.79284291400159 - 0.85373472095314 * r;
			}

			float SNoise(float2 v)
			{
				const float4 C = float4(0.211324865405187, // (3.0-sqrt(3.0))/6.0
				                        0.366025403784439, // 0.5*(sqrt(3.0)-1.0)
				                        - 0.577350269189626, // -1.0 + 2.0 * C.x
				                        0.024390243902439); // 1.0 / 41.0
				// First corner
				float2 i = floor(v + dot(v, C.yy));
				float2 x0 = v - i + dot(i, C.xx);

				// Other corners
				float2 i1;
				i1.x = step(x0.y, x0.x);
				i1.y = 1.0 - i1.x;

				// x1 = x0 - i1  + 1.0 * C.xx;
				// x2 = x0 - 1.0 + 2.0 * C.xx;
				float2 x1 = x0 + C.xx - i1;
				float2 x2 = x0 + C.zz;

				// Permutations
				i = Mod289(i); // Avoid truncation effects in permutation
				float3 p = Permute(Permute(i.y + float3(0.0, i1.y, 1.0))
					+ i.x + float3(0.0, i1.x, 1.0));

				float3 m = max(0.5 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0.0);
				m = m * m;
				m = m * m;

				// Gradients: 41 points uniformly over a line, mapped onto a diamond.
				// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
				float3 x = 2.0 * frac(p * C.www) - 1.0;
				float3 h = abs(x) - 0.5;
				float3 ox = floor(x + 0.5);
				float3 a0 = x - ox;

				// Normalise gradients implicitly by scaling m
				m *= TaylorInvSqrt(a0 * a0 + h * h);

				// Compute final noise value at P
				float3 g;
				g.x = a0.x * x0.x + h.x * x0.y;
				g.y = a0.y * x1.x + h.y * x1.y;
				g.z = a0.z * x2.x + h.z * x2.y;
				return 130.0 * dot(m, g);
			}

			//-----------------
			//End Random

			//最高0.5
			float CalcUVScale(float x)
			{
				float y = x - 0.5;
				y = -10 * y * y + 0.5;
				y = max(y, 0);
				return y;
			}

			float CalcGrain(float x)
			{
				float y = x - 0.5;
				y = -4 * y * y + 1;
				return y;
			}

			half3 ApplyGrain(half3 input, float2 uv, TEXTURE2D_PARAM(GrainTexture, GrainSampler), float intensity,
			                 float response, float2 scale, float2 offset)
			{
				// Grain in range [0;1] with neutral at 0.5
				half grain = SAMPLE_TEXTURE2D(GrainTexture, GrainSampler, uv * scale + offset).w;

				// Remap [-1;1]
				grain = (grain - 0.5) * 2.0;

				// Noisiness response curve based on scene luminance
				float lum = 1.0 - sqrt(Luminance(input));
				lum = lerp(1.0, lum, response);

				return input * grain * intensity * lum;
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
				float2 resolution = _ScreenParams.xy;
				float time = _ProgressCtrl; //_Time.y;

				//uv scale
				//---------------------
				float intensity = CalcUVScale(time);
				uv.x = uv.x * (1 - intensity * _Frequency);

				//Jitter
				//---------------------
				half strength = 0.5 + 0.5 * cos((time * 2 + 1) * PI);

				//prepare uv
				float uv_y = uv.y * resolution.y;
				float noise_wave_1 = SNoise(float2(uv_y * 0.01, time * _Speed * 20)) * (strength * _Amount * 32.0);
				float noise_wave_2 = SNoise(float2(uv_y * 0.02, time * _Speed * 10)) * (strength * _Amount * 4.0);
				float noise_wave_x = noise_wave_1 * noise_wave_2 / resolution.x;
				float uv_x = uv.x + noise_wave_x;

				float rgbSplit_uv_x = (_RGBSplit * 50 + (20.0 * strength + 10)) * noise_wave_x / resolution.x;

				//sample RGB color
				half4 colorGB = SampleSrcTex(float2(uv_x, uv.y));
				half4 colorR = SampleSrcTex(float2(uv_x + rgbSplit_uv_x, uv.y));

				half4 col = half4(colorR.r, colorGB.g, colorGB.b, 1);

				//FilmGrain
				//------------------
				intensity = CalcGrain(time);
				col.rgb += ApplyGrain(1, uv, _GrainTex, sampler_GrainTex, 5 * intensity, 0.8, float2(5, 5),
				                      float2(noise_wave_1, noise_wave_2));

				col.rgb *= (1 - _Dark * intensity);

				return col;
			}
			ENDHLSL
		}
	}
}