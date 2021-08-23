Shader "MyRP/ScreenEffect/S_SketchBook"
{
	Properties
	{
		_AngleNum("Angle Number", Range(0, 10)) = 4
		_SampleNum("Sample Number", Range(0, 20)) = 9
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
			Name "Sketch Book"

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

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_point_clamp_sampler);
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			TEXTURE2D(_SrcTex);

			float _AngleNum;
			float _SampleNum;

			inline half4 SampleSrcTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
			}

			half3 GetCol(float2 pos)
			{
				// take aspect ratio into account
				float2 uv = pos / _ScreenParams.xy;
				half3 c1 = SampleSrcTex(uv).rgb;
				// 影响不大
				// float4 e = smoothstep(-0.05, 0.0, float4(uv, 1 - uv));
				// c1 = lerp(1, c1, e.x * e.y * e.z * e.w);
				float d = clamp(dot(c1.rgb, float3(-0.5, 1., -0.5)), 0.0, 1.0);
				return min(lerp(c1, 0.7, 1.8 * d), 0.7);
			}

			float GetVal(float2 pos)
			{
				half3 c = GetCol(pos);
				return 0.33333 * (c.r + c.g + c.b);
			}

			float2 GetGrad(float2 pos, float eps)
			{
				float2 d = float2(eps, 0.);
				return float2(
					GetVal(pos + d.xy) - GetVal(pos - d.xy),
					GetVal(pos + d.yx) - GetVal(pos - d.yx)
				) / eps / 2.;
			}


			half3 ClipColor(half3 c)
			{
				float l = Luminance(c);
				float n = min(min(c.r, c.g), c.b);
				float x = max(max(c.r, c.g), c.b);

				if (n < 0.)
				{
					c.r = l + ((c.r - l) * l) / (l - n);
					c.g = l + ((c.g - l) * l) / (l - n);
					c.b = l + ((c.b - l) * l) / (l - n);
				}
				if (x > 1.25)
				{
					c.r = l + ((c.r - l) * (1. - l)) / (x - l);
					c.g = l + ((c.g - l) * (1. - l)) / (x - l);
					c.b = l + ((c.b - l) * (1. - l)) / (x - l);
				}
				return c;
			}

			half3 SetLum(half3 c, float l)
			{
				float d = l - Luminance(c);
				c = c + d;
				return ClipColor(.85 * c); //+ step(d, 0.01) * 0;// *0 is dark color
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
				float isline = 0;
				// half3 col2 = 0;
				// float sum = 0;

				float angleStep = TWO_PI / _AngleNum;
				float dy = _ScreenParams.y / 920.0;

				UNITY_LOOP
				for (float i = 0; i < _AngleNum; i++)
				{
					float ang = angleStep * (i + 0.8);
					float2 v = float2(cos(ang), sin(ang));
					float2 invV = v.yx * float2(1, -1);
					UNITY_LOOP
					for (float j = 0; j < _SampleNum; j++)
					{
						float dyj = dy * j;
						float weight = j / _SampleNum;
						
						float2 dpos = invV * dyj;
						float2 dpos2 = 5.0 * 0.5 * v.xy * dyj * weight;

						float s = 3.5;

						float2 pos2 = pos + s * dpos + dpos2;
						float2 g = GetGrad(pos2, 0.08);
						//越靠近g方向 权重越高
						float fact = dot(g, v) - 0.5 * abs(dot(g, invV));
						// float fact2 = dot(normalize(g + float2(0.0001, 0.0001)), v.yx * float2(1, -1));

						fact = clamp(fact, 0.0, 0.05);
						// fact2 = abs(fact2);

						fact *= 1.0 - weight;
						isline += fact;
						// col2 += fact2;
						// sum += fact2;
					}
				}
				isline /= _SampleNum * _AngleNum * 0.65 / sqrt(_ScreenParams.y);
				// return isline;
				// col2 /= sum;
				isline *= 1.6;
				isline = 1.0 - isline;
				isline *= isline * isline;
				// return isline;

				float2 s2 = sin(pos.xy * 0.1 / sqrt(_ScreenParams.y / 720.0));
				float3 karo = 1;
				karo -= 0.75755 * float3(0.25, 0.1, 0.1) * dot(exp(-s2 * s2 * 80.0), float2(1, 1));
				float r = length(pos - _ScreenParams.xy * 0.5) / _ScreenParams.x;
				float vign = 1.0 - r * r * r;
				// karo = 1;
				// vign = 1;
				half3 color = half3(isline.x /* * col2 */ * karo * vign);
				half3 origCol = SampleSrcTex(uv).rgb;
				half3 overlayCol = half3(0.3755, 0.05, 0.0) * origCol;
				// overlayCol = origCol;
				color = SetLum(1.25 * overlayCol.rgb, Luminance(color));
				color -= 0.75 - clamp(origCol.r + origCol.g + origCol.b, 0.0, 0.75);

				return half4(color, 1.0);
			}
			ENDHLSL
		}
	}
}