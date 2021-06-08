Shader "MyRP/ScreenEffect/S_BlackHole"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl",Range(0,1))=0.5
		[Toggle]_3DUV("_3DUV",Int)=0
		_UVOffset("UV Offset",Vector)=(0.0,0.0,0,0) //uv偏移 -0.5~0.
		_TwirlStrength("Twirl Strength",float)=10
		_PlayerPos("Player Pos",Vector)=(0.5,0.0,0,0) //角色位置 0~1
		_FrontTex("Front Texture",2D)="white"{}
		_BackTex("Back Texture",2D)="black"{}
		_DistortUVTex("Distort UV Texture",2D)="black"{}
		_DistortUVStart("Distort UV Start",Range(0,1))=0.2
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Black Hole"
			ZTest Always
			ZWrite Off
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile_local_fragment _ _3DUV_ON

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

			TEXTURE2D_X(_FrontTex);
			TEXTURE2D_X(_BackTex);
			TEXTURE2D_X(_DistortUVTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _ProgressCtrl;
			float4 _UVOffset;
			float _TwirlStrength;
			float _DistortUVStart;

			#if _3DUV_ON
			float2 _PlayerPos;
			#endif

			float Remap(float x, float t1, float t2, float s1, float s2)
			{
				return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
			}

			float2 SafeNormalize(float2 inVec)
			{
				float dp2 = max(FLT_MIN, dot(inVec, inVec));
				return inVec * rsqrt(dp2);
			}

			#if _3DUV_ON


			#endif

			float2 ScaleUV(float2 uv, float2 center, float ctrl)
			{
				ctrl = smoothstep(0, 1, ctrl);
				float2 dir = uv - center;
				dir = SafeNormalize(dir);
				// dir = lerp(SafeNormalize(dir), dir, ctrl * 0.5);
				float2 delta = ctrl * dir;
				uv = uv + delta;
				return uv;
			}

			float2 Rot(float2 delta, float angle = 0)
			{
				float c, s;
				sincos(angle, c, s);
				float x = c * delta.x - s * delta.y;
				float y = s * delta.x + c * delta.y;

				return float2(x, y);
			}

			float2 Bezier(float2 uv, float2 center, float t)
			{
				float2 down = uv - center;
				float2 left = Rot(uv - center);
				float2 up = -down;
				float2 right = -left;

				float2 points[9];

				points[0] = down;
				points[1] = left * 8;
				points[2] = up * 16;
				points[3] = right * 28;
				points[4] = down * 36;
				points[5] = left * 48;
				points[6] = up * 48;
				points[7] = right * 48;
				points[8] = down * 20;

				for (int i = 8; i >= 0; i--)
				{
					for (int j = 0; j < i; j++)
					{
						points[j] = lerp(points[j], points[j + 1], t);
					}
				}

				return points[0] + center;
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
				float ctrl = _ProgressCtrl;
				float2 uv = IN.uv;


				float2 bezier = uv; //ScaleUV(uv, _UVOffset.xy, ctrl);
				bezier = Bezier(bezier, _UVOffset.xy, ctrl);

				float isBack = 0;
				if (bezier.x < 0 || bezier.y < 0 || bezier.x > 1 || bezier.y > 1)
				{
					isBack = 1;
				}

				//backTex
				//-----------
				half3 backCol = SAMPLE_TEXTURE2D(_BackTex, s_linear_clamp_sampler, bezier).rgb;
				float backLine = max(0, ctrl - _DistortUVStart)
					* (SAMPLE_TEXTURE2D(_DistortUVTex, s_linear_clamp_sampler, bezier).r);
				backCol += 0 * backLine;

				//frontTex
				//-----------
				half3 frontCol = SAMPLE_TEXTURE2D(_FrontTex, s_linear_clamp_sampler, uv).rgb;

				half3 finalCol = lerp(backCol, frontCol, isBack);

				return half4(finalCol, 1);
			}
			ENDHLSL
		}
	}
}