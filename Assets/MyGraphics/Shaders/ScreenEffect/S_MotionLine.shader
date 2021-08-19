//https://www.shadertoy.com/view/3tl3z2
Shader "MyRP/ScreenEffect/S_MotionLine"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	struct a2v
	{
		uint vertexID:SV_VertexID;
	};

	struct v2f
	{
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
	};

	TEXTURE2D(_Src0Tex);
	TEXTURE2D(_Src1Tex);

	SAMPLER(s_linear_clamp_sampler);
	SAMPLER(s_point_clamp_sampler);

	v2f vert(a2v IN)
	{
		v2f o;
		o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
		return o;
	}

	inline half2 ColMul(half2 a, float b)
	{
		return mul(float2x2(a.xy, -a.y, a.x), float2(cos(b), sin(b)));
	}

	inline half MaxSize()
	{
		// 正常屏幕X都比较大 
		// return max(_ScreenParams.x,_ScreenParams.y);
		return _ScreenParams.x;
	}
	ENDHLSL

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
			Name "A"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 frag(v2f IN) : SV_Target
			{
				half4 col = .7 * length(SAMPLE_TEXTURE2D(_Src0Tex, s_linear_clamp_sampler, IN.uv).rbg);
				// * smoothstep(1.,.9,max(u.x,u.y)); // continuous wrap
				return col;
			}
			ENDHLSL
		}

		Pass
		{
			Name "B"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 frag(v2f IN) : SV_Target
			{
				float2 pos = IN.vertex.xy;
				float2 uv = IN.uv.xy;
				float size = MaxSize();
				float invSize = 1.0 / size;
				half4 col = 0;
				for (float n = 0.0; n < size; n++)
				{
					half2 xn = SAMPLE_TEXTURE2D(_Src0Tex, s_point_clamp_sampler, float2(n*invSize,uv.y)).rg;
					half2 yn = SAMPLE_TEXTURE2D(_Src1Tex, s_point_clamp_sampler, float2(uv.x,n*invSize)).ba;
					half2 a = -TWO_PI * _ScreenParams.xy * (uv - 0.5) * (n / size);

					col.ba += ColMul(xn, a.x);
					col.rg += ColMul(yn, a.y);
				}
				return col;
			}
			ENDHLSL
		}

		Pass
		{
			Name "C"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;

				half2 temp = SAMPLE_TEXTURE2D(_Src0Tex, s_linear_clamp_sampler, uv).rg;

				float2 dir = 2. * uv - 1.;
				float s = sign(dot(dir, cos(.1 * _Time.y - float2(0, HALF_PI))));
				temp = ColMul(temp, 3. * _Time.y * s); // 13: phase shift with time

				return half4(temp, 0, 0);
			}
			ENDHLSL
		}

		Pass
		{
			Name "D"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 frag(v2f IN) : SV_Target
			{
				float2 pos = IN.vertex.xy;
				float2 uv = IN.uv.xy;
				float size = MaxSize();
				float invSize = 1.0 / size;
				half4 col = 0;
				for (float n = 0.; n < size; n++)
				{
					float m = frac(n * invSize + 0.5); // W to warp 0,0 to mid-window.
					half2 xn = SAMPLE_TEXTURE2D(_Src0Tex, s_point_clamp_sampler, float2(m, uv.y)).rg;
					half2 yn = SAMPLE_TEXTURE2D(_Src1Tex, s_point_clamp_sampler, float2(uv.x, m )).ba;
					half2 a = TWO_PI * _ScreenParams.xy * uv * (n / size);

					col.ba += ColMul(xn, a.x);
					col.rg += ColMul(yn, a.y);
				}
				col /= size;

				return col;
			}
			ENDHLSL
		}

		Pass
		{
			Name "E"

			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 frag(v2f IN) : SV_Target
			{
				float c = SAMPLE_TEXTURE2D(_Src0Tex, s_linear_clamp_sampler, IN.uv).r;
				c = 0.5 + 0.5 * c;
				return half4(c.rrr, 0.5);
			}
			ENDHLSL
		}
	}
}