Shader "MyRP/Skinner/ParticleKernels"
{
	HLSLINCLUDE
	// #pragma enable_d3d11_debug_symbols

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

	struct outMRT
	{
		float4 pos : SV_Target0;
		float4 vel : SV_Target1;
		float4 rot : SV_Target2;
	};

	TEXTURE2D(_SourcePositionTex0);
	float4 _SourcePositionTex0_TexelSize;
	TEXTURE2D(_SourcePositionTex1);
	float4 _SourcePositionTex1_TexelSize;
	TEXTURE2D(_PositionTex);
	TEXTURE2D(_VelocityTex);
	TEXTURE2D(_RotationTex);


	half2 _Damper; // drag, speed_limit
	half3 _Gravity;
	half2 _Life; // dt / max_life, dt / (max_life * speed_to_life)
	half2 _Spin; // max_spin * dt, speed_to_spin * dt
	half2 _NoiseParams; // frequency, amplitude * dt
	float3 _NoiseOffset;

	//也可以用textureName.GetDimensions()  但是效率比较低  具体看  https://zhuanlan.zhihu.com/p/400016561 评论
	#define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)
	// #define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2 * textureName##_TexelSize.zw)
	// SAMPLER(s_point_clamp_sampler);
	// #define SampleTex(textureName, coord2) SAMPLE_TEXTURE2D(textureName, s_point_clamp_sampler, coord2)

	v2f vert(a2v IN)
	{
		v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
		return o;
	}

	float4 NewParticlePosition(float2 uv)
	{
		//随机一个坐标点
		float2 pos = float2(UVRandom(uv, _Time.x), 0.5) * _SourcePositionTex1_TexelSize.zw;
		float3 p = SampleTex(_SourcePositionTex1, pos).xyz;
		return float4(p, 1.0);
	}

	float4 NewParticleVelocity(float2 uv)
	{
		//因为跟上面就隔了一帧数,所以映射的pos不会差很大
		float2 pos = float2(UVRandom(uv, _Time.x), 0.5) * _SourcePositionTex0_TexelSize.zw;
		float3 p0 = SampleTex(_SourcePositionTex0, pos).xyz;
		float3 p1 = SampleTex(_SourcePositionTex1, pos).xyz;
		float3 v = (p1 - p0) * unity_DeltaTime.y;
		v = min(v,FLT_MAX);
		v *= 1 - UVRandom(uv, 12) * 0.5;
		float w = max(length(v), FLT_EPS);
		return float4(v, w);
	}

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
				//RT是可以存负数的  但是我这里修改过了
				return float4(-1e+6, -1e+6, -1e+6, UVRandom(IN.uv, 16));
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
				//会出现1/0的情况  不同GPU结果不一样  是Nan 还是正无穷(INF) 或者是 别的值
				//不用FLT_MIN是避免 FLT_MAX+1 溢出
				return FLT_EPS;
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

			float4 UpdatePositionFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				int2 pos = IN.pos.xy; //float2 x.5 也可以不-0.5 直接转换才int2
				float4 p = SampleTex(_PositionTex, pos);
				float4 v = SampleTex(_VelocityTex, pos);
				float rnd = 1 + UVRandom(uv, 17) * 0.5;
				//v越小 说明越平稳 粒子需要越不明显  则life衰减越快
				//v越大 则可能走MaxLife
				//而且这里的v.w是初始速度
				p.w -= max(_Life.x, _Life.y / v.w) * rnd;

				//p.w第一次是很大的负数
				if (p.w > 0)
				{
					float lv = max(length(v.xyz), FLT_EPS);
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

			float4 UpdateVelocityFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				int2 pos = IN.pos.xy;

				float4 p = SampleTex(_PositionTex, pos);

				//==1的时候是刚创建
				if (p.w < 1.0)
				{
					float4 v = SampleTex(_VelocityTex, pos);

					v.xyz = v.xyz * _Damper.x + _Gravity.xyz;
					//_NoiseOffset
					float3 np = (p.xyz + _NoiseOffset) * _NoiseParams.x;
					float3 n1 = snoise_grad(np);
					float3 n2 = snoise_grad(np + float3(21.83, 13.28, 7.32));
					//v.w还是初始速度的长度  并没有更新
					v.xyz += cross(n1, n2) * _NoiseParams.y;

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


			float4 UpdateRotationFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				int2 pos = IN.pos.xy;

				float4 r = SampleTex(_RotationTex, pos);
				float4 v = SampleTex(_VelocityTex, pos);

				float delta = min(_Spin.x, length(v.xyz) * _Spin.y);
				delta *= 1 - UVRandom(uv, 18) * 0.5;

				float sn, cs;
				sincos(delta, sn, cs);
				float4 dq = float4(RotationAxis(uv) * sn, cs);
				dq = QMult(dq,r);

				// return normalize(dq);

				//比如说animator关闭 玩家刚开始是静止的  概率normalize nan
				float len2 = Sqr(dq);
				if(len2 == 0)
				{
					return float4(0, 0, 0, 1);
				}
				else
				{
					return dq * rsqrt(len2);
				}
			}
			ENDHLSL
		}

		//6
		Pass
		{
			Name "InitializeMRT"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializeMRTFragment

			outMRT InitializeMRTFragment(v2f IN)
			{
				outMRT o;
				o.pos = float4(-1e+6, -1e+6, -1e+6, UVRandom(IN.uv, 16));
				o.vel = FLT_EPS;
				o.rot = NewParticleRotation(IN.uv);
				return o;
			}
			ENDHLSL
		}

		//7
		Pass
		{
			Name "UpdateMRT"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdateMRTFragment

			outMRT UpdateMRTFragment(v2f IN)
			{
				outMRT o;

				float2 uv = IN.uv;
				int2 pos = IN.pos.xy; //float2 x.5 也可以不-0.5 直接转换才int2

				//pos
				//----------------------
				float4 p = SampleTex(_PositionTex, pos);
				float4 v = SampleTex(_VelocityTex, pos);
				float rnd = 1 + UVRandom(uv, 17) * 0.5;
				//v越小 说明越平稳 粒子需要越不明显  则life衰减越快
				//v越大 则可能走MaxLife
				//而且这里的v.w是初始速度
				p.w -= max(_Life.x, _Life.y / v.w) * rnd;

				//p.w第一次是很大的负数
				if (p.w > 0)
				{
					float lv = max(length(v.xyz), FLT_EPS);
					float3 cv = v.xyz * min(lv, _Damper.y) / lv;
					p.xyz += cv * unity_DeltaTime.x;
				}
				else
				{
					p = NewParticlePosition(uv);
				}

				o.pos = p;

				//vel
				//-------------------------
				//==1的时候是刚创建
				if (p.w < 1.0)
				{
					float3 cv = v.xyz * _Damper.x + _Gravity.xyz;
					//_NoiseOffset
					float3 np = (p.xyz + _NoiseOffset) * _NoiseParams.x;
					float3 n1 = snoise_grad(np);
					float3 n2 = snoise_grad(np + float3(21.83, 13.28, 7.32));
					//v.w初始速度没有更新
					v.xyz = cv + cross(n1, n2) * _NoiseParams.y;
				}
				else
				{
					v = NewParticleVelocity(uv);
				}

				o.vel = v;

				//rot
				//---------------
				float4 r = SampleTex(_RotationTex, pos);

				float delta = min(_Spin.x, length(v.xyz) * _Spin.y);
				delta *= 1 - UVRandom(uv, 18) * 0.5;

				float sn, cs;
				sincos(delta, sn, cs);
				float4 dq = float4(RotationAxis(uv) * sn, cs);
				dq = QMult(dq,r);

				// return normalize(dq);

				//比如说animator关闭 玩家刚开始是静止的  概率normalize nan
				float len2 = Sqr(dq);
				if(len2 == 0)
				{
					dq = float4(0, 0, 0, 1);
				}
				else
				{
					dq = dq * rsqrt(len2);
				}

		
				o.rot = dq;

				return o;
			}
			ENDHLSL
		}
	}
}