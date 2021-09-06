Shader "MyRP/Skinner/ParticleKernels"
{
	HLSLINCLUDE

	#pragma enable_d3d11_debug_symbols
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "SkinnerCommon.hlsl"
	#include "SimplexNoiseGrad3D.hlsl"

	struct a2v
	{
		uint vertexID:SV_VertexID;
	};

	struct v2f
	{
		float4 pos:SV_POSITION;
		float2 uv:TEXCOORD0;
	};

	TEXTURE2D(_SourcePositionTex0);
	float4 _SourcePositionTex0_TexelSize;
	TEXTURE2D(_SourcePositionTex1);
	float4 _SourcePositionTex1_TexelSize;
	TEXTURE2D(_PositionTex);
	float4 _PositionTex_TexelSize;
	TEXTURE2D(_VelocityTex);
	float4 _VelocityTex_TexelSize;
	TEXTURE2D(_RotationTex);
	float4 _RotationTex_TexelSize;


	half2 _Damper; // drag, speed_limit
	half3 _Gravity;
	half2 _Life; // dt / max_life, dt / (max_life * speed_to_life)
	half2 _Spin; // max_spin * dt, speed_to_spin * dt
	half2 _NoiseParams; // frequency, amplitude * dt
	float3 _NoiseOffset;

	//也可以用textureName.GetDimensions()
	#define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2 * textureName##_TexelSize.zw)
	// SAMPLER(s_point_clamp_sampler);
	// #define SampleTex(textureName, coord2) SAMPLE_TEXTURE2D(textureName, s_point_clamp_sampler, coord2)

	v2f vert(a2v IN)
	{
		v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
		return o;
	}
	ENDHLSL
	SubShader
	{
		ZTest Always
		ZWrite Off
		Cull Off

		//0
		Pass
		{
			Name "InitializePosition"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializePositionFragment

			float4 InitializePositionFragment(v2f IN):SV_Target
			{
				//a far point and random life
				//是可以存在负数的
				return float4(1e+6, 1e+6, 1e+6, UVRandom(IN.uv, 16) - 0.5);
			}
			ENDHLSL
		}
		
		//1
		Pass
		{
			Name "InitializeVelocity"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializeVelocityFragment

			float4 InitializeVelocityFragment(v2f IN):SV_Target
			{
				return 1e-6;
			}
			ENDHLSL
		}
		
		//2
		Pass
		{
			Name "InitializeRotation"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializeRotationFragment

			float4 NewParticleRotation(float2 uv)
			{
				// Uniform random unit quaternion
				// http://www.realtimerendering.com/resources/GraphicsGems/gemsiii/urot.c
				float r = UVRandom(uv, 13);
				float r1 = sqrt(1 - r);
				float r2 = sqrt(r);
				float t1 = TWO_PI * UVRandom(uv, 14);
				float t2 = TWO_PI * UVRandom(uv, 15);
				return float4(sin(t1) * r1, cos(t1) * r1, sin(t2) * r2, cos(t2) * r2);
			}

			float4 InitializeRotationFragment(v2f IN):SV_Target
			{
				return NewParticleRotation(IN.uv);
			}
			ENDHLSL
		}
		
		//3
		Pass
		{
			Name "UpdatePosition"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdatePositionFragment

			float4 NewParticlePosition(float2 uv)
			{
				//随机一个坐标点
				uv = float2(UVRandom(uv, _Time.x), 0.5);
				float3 p = SampleTex(_SourcePositionTex1, uv).xyz;
				return float4(p, 0.5);
			}

			float4 UpdatePositionFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				float4 p = SampleTex(_PositionTex, uv);
				float4 v = SampleTex(_VelocityTex, uv);
				float rnd = 1 + UVRandom(uv, 17) * 0.5;
				//v越小 说明越平稳 粒子需要越不明显  则life衰减越快
				//v越大 则可能走MaxLife
				//而且这里的v.w是初始速度
				p.w -= max(_Life.x, _Life.y / v.w) * rnd;

				//p.w第一次是很大的负数
				if (p.w > -0.5)
				{
					float lv = max(length(v.xyz), 1e-6);
					v.xyz = v.xyz * min(lv, _Damper.y) / lv;
					p.xyz += v.xyz * unity_DeltaTime.x;
					return p;
				}
				else
				{
					return NewParticlePosition(uv);
				}
			}
			ENDHLSL
		}
		
		//4
		Pass
		{
			Name "UpdateVelocity"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdateVelocityFragment

			float4 NewParticleVelocity(float2 uv)
			{
				//因为跟上面就隔了一帧数,所以映射的pos不会差很大
				uv = float2(UVRandom(uv, _Time.x), 0.5);
				float3 p0 = SampleTex(_SourcePositionTex0, uv).xyz;
				float3 p1 = SampleTex(_SourcePositionTex1, uv).xyz;
				float3 v = (p1 - p0) * unity_DeltaTime.y;
				v *= 1 - UVRandom(uv, 12) * 0.5;
				float w = max(length(v), 1e-6);
				return float4(v, w);
			}

			float4 UpdateVelocityFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				float4 p = SampleTex(_PositionTex, uv);

				//等于0.5的时候是刚创建
				if (p.w < 0.5)
				{
					float4 v = SampleTex(_VelocityTex, uv);

					v.xyz = v.xyz * _Damper.x + _Gravity.xyz;
					//_NoiseOffset
					float3 np = (p.xyz + _NoiseOffset) * _NoiseParams.x;
					float3 n1 = snoise_grad(np);
					float3 n2 = snoise_grad(np + float3(21.83, 13.28, 7.32));
					v.xyz += cross(n1, n2) * _NoiseParams.y;

					//v.w初始速度没有更新
					return v;
				}
				else
				{
					return NewParticleVelocity(uv);
				}
			}
			ENDHLSL
		}
		
		//5
		Pass
		{
			Name "UpdateRotation"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdateRotationFragment


			// Deterministic random rotation axis.
			float3 RotationAxis(float2 uv)
			{
				// Uniformaly distributed points
				// http://mathworld.wolfram.com/SpherePointPicking.html
				float u = UVRandom(uv, 10) * 2 - 1;
				float u2 = sqrt(1 - u * u);
				float sn, cs;
				sincos(UVRandom(uv, 11) * TWO_PI, sn, cs);
				return float3(u2 * cs, u2 * sn, u);
			}

			float4 UpdateRotationFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				float4 r = SampleTex(_RotationTex, uv);
				float4 v = SampleTex(_VelocityTex, uv);

				float delta = min(_Spin.x, length(v.xyz) * _Spin.y);
				delta *= 1 - UVRandom(uv, 18) * 0.5;

				float sn, cs;
				sincos(delta, sn, cs);
				float4 dq = float4(RotationAxis(uv) * sn, cs);

				return normalize(QMult(dq, r));
			}
			ENDHLSL
		}
	}
}