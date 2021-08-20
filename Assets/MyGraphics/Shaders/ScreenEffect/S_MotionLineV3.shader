Shader "MyRP/ScreenEffect/S_MotionLineV3"
{
	Properties
	{
		_CellSize("Cell Size",Vector) = (200,100,0,0)
		_TimeLoop ("Time Loop",float) = 0.5 //需要>0
		_IntensityCycle ("Intensity Cycle",float) = 1 //需要>0
		_AlphaIntensity ("Alpha Intensity",Range(0,3)) = 0.
		_ScaleIntensity ("Scale Intensity",Range(0,1)) = 0.8
		_NoiseThreshold ("Noise Threshold",Range(0.001,0.999)) = 0.05
		_NoiseSeed ("Noise Seed",Vector) = (10086,23333,66666,0)
		_MoveDir("Move Dir",float) = 0
		_MoveSpeed("Move Speed",Vector) = (0,0,0,1)
		_MotionLineTex("Motion Line Texture",2D) = "black"{}
	}

	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "MotionLineV3"
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
				uint vertexID:SV_VertexID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			TEXTURE2D(_SrcTex);
			SAMPLER(s_linear_clamp_sampler);

			// 4*4 = 16
			#define TEX_COUNT 4
			#define TEX_INV_COUNT 1.0/TEX_COUNT

			float2 _CellSize;
			float _TimeLoop;
			float _IntensityCycle;
			float _AlphaIntensity;
			float _ScaleIntensity;
			float _NoiseThreshold;
			float3 _NoiseSeed;
			float _MoveDir;
			float4 _MoveSpeed;
			TEXTURE2D(_MotionLineTex);


			float2 Rot(float2 delta, float angle = 0)
			{
				float c, s;
				sincos(angle, c, s);
				float x = c * delta.x - s * delta.y;
				float y = s * delta.x + c * delta.y;

				return float2(x, y);
			}

			inline float RandomNoise(float2 seed)
			{
				//return frac(abs(sin(dot(seed * 1234.5678, float2(127.1, 311.7)))) * 43758.5453123);
				float3 q = float3(dot(seed, float2(127.1, 311.7)),
				                  dot(seed, float2(269.5, 183.3)),
				                  dot(seed, float2(419.2, 371.9)));
				return frac(sin(q + _NoiseSeed) * 43758.5453);
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
				float time = _Time.y / 2;
				float2 moveDis = fmod(_MoveSpeed.xy + time * _MoveSpeed.zw, _TimeLoop);
				float2 newUV = Rot(uv - 0.5, (_MoveDir + 0.5) * PI) + 0.5 - moveDis;
				float2 newPos = newUV * _ScreenParams;
				float2 index = ceil(newPos / _CellSize);
				newUV = fmod(newUV * _ScreenParams.xy, _CellSize) / _CellSize;
				newUV = ((1 - sign(newUV)) / 2.0) + newUV;

				float rd0 = RandomNoise(index);
				float rd1 = RandomNoise(index.yx);

				float isShow = step(_NoiseThreshold, rd0) * step(1.0 - _NoiseThreshold, rd1);

				float rd2 = ceil(RandomNoise(index.xx) * TEX_COUNT) * TEX_INV_COUNT;
				float rd3 = ceil(RandomNoise(index.yy) * TEX_COUNT) * TEX_INV_COUNT;

				//不能这么写
				// 固定格子 改用 123456789 等等
				// 中间 是不是可以穿插呢
				float alpha = (1 + 5 * RandomNoise(index.xy * index.yx))
					- (_AlphaIntensity * ((fmod(time, 5 * _IntensityCycle) - _IntensityCycle) / _IntensityCycle));
				alpha = saturate(0.5 + alpha);

				newUV = (newUV - 0.5) / lerp(_ScaleIntensity, 1, alpha) + 0.5;
				newUV = saturate(newUV);
				float2 texUV = float2(rd2, rd3) + newUV * TEX_INV_COUNT;
				float intensity = SAMPLE_TEXTURE2D(_MotionLineTex, s_linear_clamp_sampler, texUV).r;

				half4 col = 0;
				col.r = isShow * alpha * intensity;

				return col;
			}
			ENDHLSL
		}

	}
}