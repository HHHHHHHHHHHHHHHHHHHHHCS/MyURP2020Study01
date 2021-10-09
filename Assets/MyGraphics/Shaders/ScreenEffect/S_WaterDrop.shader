Shader "MyRP/ScreenEffect/S_WaterDrop"
{
	Properties
	{
		_Offset("Offset", Range(0.0,5.0)) = 2.0
		_Radio("Radio", Range(0.0,5.0)) = 1.0
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "WaterDrop"
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

			#define MAX_RADIUS 1
			#define DOUBLE_HASH 0
			#define HASHSCALE1 0.1031
			#define HASHSCALE3 float3(.1031, .1030, .0973)


			float _Offset;
			float _Radio;

			float Hash12(float2 p)
			{
				float3 p3 = frac(p.xyx * HASHSCALE1);
				p3 += dot(p3, p3.yzx + 19.19);
				return frac((p3.x + p3.y) * p3.z);
			}

			float2 Hash22(float2 p)
			{
				float3 p3 = frac(p.xyx * HASHSCALE3);
				p3 += dot(p3, p3.yzx + 19.19);
				return frac((p3.xx + p3.yz) * p3.zy);
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
				float time = _Time.y;

				float2 uv = IN.uv;
				float2 frag = uv;

				frag.x *= _Radio;
				frag = frag * _Offset * 1.5;

				float2 p0 = floor(frag);
				float2 circles = 0.0;

				for (int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i)
				{
					for (int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j)
					{
						float2 pi = p0 + float2(j, i);
						float2 hash = pi;
						float2 p = pi + Hash22(hash);
						//hash12 添加随机
						float t = frac(0.5 * time + Hash12(hash));
						float2 v = p - frag;
						//半径
						float d = length(v) - (MAX_RADIUS + 1.0) * t;
						float h = 1e-3;
						float d1 = d - h;
						float d2 = d + h;
						float p1 = sin(31.0 * d1) * smoothstep(-0.6, -0.3, d1) * smoothstep(0.0, -0.3, d1);
						float p2 = sin(31.0 * d2) * smoothstep(-0.6, -0.3, d2) * smoothstep(0.0, -0.3, d2);
						circles += 0.5 * normalize(v) * ((p2 - p1) / (2.0 * h) * (1.0 - t) * (1.0 - t));
					}
				}

				// 两轮循环添加了weight个波(取平均)
				float weight = MAX_RADIUS * 2 + 1;
				weight *= weight;
				circles /= weight;
				float lerpVal = smoothstep(0.1, 0.6, abs(frac(0.05 * time + 0.5) * 2.0 - 1.0));
				float intensity = lerp(0.01, 0.05, lerpVal);
				float3 n = float3(circles, sin(dot(circles, circles)));
				half3 colorRipple = SAMPLE_TEXTURE2D_LOD(_SrcTex, sampler_SrcTex, uv+intensity*n.xy, 0).rgb;
				float colorGloss = 5.0 * pow(clamp(dot(n, normalize(float3(1.0, 0.7, 0.5))), 0.0, 1.0), 6.0);
				half3 color = colorRipple + colorGloss.xxx;
				return half4(color, 1.0);
			}
			ENDHLSL
		}
	}
}