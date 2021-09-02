Shader "MyRP/Skinner/ParticleKernels"
{
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "SkinnerCommon.hlsl"
	#include "SimplexNoiseGrad3D.hlsl"

	struct a2v
	{
		uint id:SV_InstanceID;
	};

	struct v2f
	{
		float4 pos:SV_POSITION;
		float2 uv:TEXCOORD0;
	};

	TEXTURE2D(_SourcePositionBuffer0);
	TEXTURE2D(_SourcePositionBuffer1);
	TEXTURE2D(_PositionBuffer);
	TEXTURE2D(_VelocityBuffer);
	TEXTURE2D(_RotationBuffer);

	SAMPLER(s_linear_clamp_sampler);

	half2 _Damper; // drag, speed_imit
	half3 _Gravity;
	half2 _Life; // dt / max_life, dt / (max_life * speed_to_life)
	half2 _Spin; // max_spin * dt, speed_to_spin * dt
	half2 _NoiseParams; // frequency, amplitude * dt
	float3 _NoiseOffset;

	v2f vert(a2v IN)
	{
		v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(IN.id);
		o.uv = GetFullScreenTriangleTexCoord(IN.id);
		return o;
	}
	ENDHLSL
	SubShader
	{
		//0
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializePositionFragment

			float4 InitializePositionFragment(v2f IN):SV_Target
			{
				//a far point and random life
				return float4(1e+6, 1e+6, 1e+6, UVRandom(IN.uv, 16) - 0.5);
			}
			ENDHLSL
		}
		//1
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializeVelocityFragment

			float4 InitializeVelocityFragment(v2f IN):SV_Target
			{
				return 0;
			}
			ENDHLSL
		}
		//2
		Pass
		{
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
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdatePositionFragment

			float4 NewParticlePosition(float2 uv)
			{
				uv = float2(UVRandom(uv, _Time.x), 0.5);
				float3 p = SAMPLE_TEXTURE2D(_SourcePositionBuffer1, s_linear_clamp_sampler, uv).xyz;
				return float4(p, 0.5);
			}

			float4 UpdatePositionFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				float4 p = SAMPLE_TEXTURE2D(_PositionBuffer, s_linear_clamp_sampler, uv);
				float4 v = SAMPLE_TEXTURE2D(_VelocityBuffer, s_linear_clamp_sampler, uv);

				float rnd = 1 + UVRandom(uv, 17) * 0.5;
				p.w -= max(_Life.x, _Life.y / v.w) * rnd;

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
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdateVelocityFragment

			float4 NewParticleVelocity(float2 uv)
			{
				uv = float2(UVRandom(uv, _Time.x), 0.5);
				float3 p0 = SAMPLE_TEXTURE2D(_SourcePositionBuffer0, s_linear_clamp_sampler, uv).xyz;
				float3 p1 = SAMPLE_TEXTURE2D(_SourcePositionBuffer1, s_linear_clamp_sampler, uv).xyz;
				float3 v = (p1 - p0) * unity_DeltaTime.y;
				v *= 1 - UVRandom(uv, 12) * 0.5;
				return float4(v, length(v));
			}

			float4 UpdateVelocityFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				float4 p = SAMPLE_TEXTURE2D(_PositionBuffer, s_linear_clamp_sampler, uv);
				float4 v = SAMPLE_TEXTURE2D(_VelocityBuffer, s_linear_clamp_sampler, uv);

				if (p.w < 0.5)
				{
					v.xyz = v.xyz * _Damper.x + _Gravity.xyz;
					float3 np = (p.xyz + _NoiseOffset) * _NoiseParams.x;
					float3 n1 = snoise_grad(np);
					float3 n2 = snoise_grad(np + float3(21.83, 13.28, 7.32));
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
				float4 r = SAMPLE_TEXTURE2D(_RotationBuffer, s_linear_clamp_sampler, uv);
				float4 v = SAMPLE_TEXTURE2D(_VelocityBuffer, s_linear_clamp_sampler, uv);

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