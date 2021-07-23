Shader "MyRP/ScreenEffect/S_RippleEffect"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl", Range(0, 1)) = 0.5
		_Reflection("Reflection Color", Color) = (0, 0, 0, 0)
		_Params1("Parameters 1", Vector) = (1, 1, 0.8, 0)
		_Params2("Parameters 2", Vector) = (1, 1, 1, 0)
		_Drop1("Drop 1", Vector) = (0.49, 0.5, 0, 0)
		_Drop2("Drop 2", Vector) = (0.50, 0.5, 0, 0)
		_Drop3("Drop 3", Vector) = (0.51, 0.5, 0, 0)
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Ripple Effect"
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

			float _ProgressCtrl;
			half4 _Reflection;
			float4 _Params1; // [ aspect, 1, scale, distance ]
			float4 _Params2; // [ 1, 1/aspect, refraction, reflection ]

			float3 _Drop1;
			float3 _Drop2;
			float3 _Drop3;

			float CalcT(float x)
			{
				float t = 25 * (x - 0.075);
				t = saturate(-(t * t) + 1);
				return smoothstep(0, 1, t);
			}

			float Wave(float2 position, float2 origin, float time)
			{
				float d = length(position - origin);
				float t = time - d * _Params1.z;
				return 2 * CalcT(t) - 1;
			}

			float AllWave(float2 position)
			{
				float t = _ProgressCtrl;
				return 0.33*(Wave(position, _Drop1.xy, t) +
					Wave(position, _Drop2.xy, t) +
					Wave(position, _Drop3.xy, t));
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
				const float2 dx = float2(0.01, 0);
				const float2 dy = float2(0, 0.01);

				float2 p = IN.uv;

				float w = AllWave(p);

				float2 dw = float2(AllWave(p + dx) - w, AllWave(p + dy) - w);

				float2 duv = dw * _Params2.xy * 0.2 * _Params2.z;
				half4 c = SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, IN.uv + duv);
				float fr = pow(length(dw) * 3 * _Params2.w, 3);
				return lerp(c, _Reflection, fr);
			}
			ENDHLSL
		}
	}
}