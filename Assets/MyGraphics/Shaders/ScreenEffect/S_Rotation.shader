Shader "MyRP/ScreenEffect/S_Rotation"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl",Range(0,1))=0.5
		_TwirlStrength("Twirl Strength",Float)=0
		_FrontTex("Front Texture",2D)="white"{}
		_BackTex("Back Texture",2D)="black"{}
		_DistortUVTex("Distort UV Texture",2D)="black"{}
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Rotation"
			ZTest Always
			ZWrite Off
			Cull Off

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

			TEXTURE2D_X(_FrontTex);
			TEXTURE2D_X(_BackTex);
			TEXTURE2D_X(_DistortUVTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _ProgressCtrl;
			float _TwirlStrength;

			float Remap(float x, float t1, float t2, float s1, float s2)
			{
				return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
			}

			float2 SafeNormalize(float2 inVec)
			{
				float dp2 = max(FLT_MIN, dot(inVec, inVec));
				return inVec * rsqrt(dp2);
			}

			float Length2(float2 v)
			{
				return dot(v, v);
			}

			float Power2(float v)
			{
				return v * v;
			}

			float2 Twirl(float2 uv, float2 center, float2 offset, float strength)
			{
				float2 delta = uv - center;
				float l2 = Length2(delta);
				float angle = strength / max(l2, lerp(0.001, 0.1, l2));
				// float angle = strength * (1 - sqrt(2 * l2));
				float s, c;
				sincos(angle, s, c);
				float x = c * delta.x - s * delta.y;
				float y = s * delta.x + c * delta.y;

				return float2(x + center.x + offset.x, y + center.y + offset.y);
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

				float2 twirl = Twirl(uv, 0.5, 0, _TwirlStrength * ctrl);

				float2 delta = uv - 0.5;
				float l2 = Length2(delta);

				half3 backCol = SAMPLE_TEXTURE2D(_BackTex, s_linear_clamp_sampler, twirl).rgb;

				half3 frontCol = SAMPLE_TEXTURE2D(_FrontTex, s_linear_clamp_sampler, uv).rgb;


				half3 col = lerp(backCol, frontCol, step(1 - l2, ctrl));

				return half4(col, 1);
			}
			ENDHLSL
		}
	}
}