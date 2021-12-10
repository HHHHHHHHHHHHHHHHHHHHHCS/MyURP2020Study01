Shader "MyRP/Skinner/TrailKernels"
{
	HLSLINCLUDE
	// #pragma enable_d3d11_debug_symbols

	#include "SkinnerCommon.hlsl"

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
		float4 orth : SV_Target2;
	};

	TEXTURE2D(_SourcePositionTex0);
	TEXTURE2D(_SourcePositionTex1);
	TEXTURE2D(_PositionTex);
	float4 _PositionTex_TexelSize;
	TEXTURE2D(_VelocityTex);
	float4 _VelocityTex_TexelSize;
	TEXTURE2D(_OrthnormTex);
	float4 _OrthnormTex_TexelSize;

	float _SpeedLimit;
	float _Drag;

	//也可以用textureName.GetDimensions()
	//uv*size理论要-0.5 但是被转换为int 自动忽略小数点
	//是会超过[0, w or h)的  超过部分 是0  所以要clamp
	//https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-to-load
	#define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)

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
				int2 uv = int2(IN.pos.x, 0);
				float3 pos = SampleTex(_SourcePositionTex1, uv).rgb;

				//a far point and random life
				//是可以存在负数的
				return float4(pos, 0);
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
				return 0;
			}
			ENDHLSL
		}

		//2
		Pass
		{
			Name "InitializeOrthnorm"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment InitializeOrthnormFragment

			float4 InitializeOrthnormFragment(v2f IN):SV_Target
			{
				return 0;
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
				int2 pos = IN.pos.xy;

				if (pos.y == 0)
				{
					//first row: just copy the source position
					return SampleTex(_SourcePositionTex1, pos);
				}

				//other row
				pos.y -= 1;

				float3 p = SampleTex(_PositionTex, pos).xyz;
				float3 v = SampleTex(_VelocityTex, pos).xyz;

				float lv = length(v);
				if (lv > 0)
				{
					p += v * (min(lv, _SpeedLimit) / lv) * unity_DeltaTime.x;
				}
				return float4(p, 0);
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
				int2 pos = IN.pos.xy;

				if (pos.y == 0)
				{
					// The first row: calculate the vertex velocity.
					// Get the average with the previous frame for low-pass filtering.
					float3 p0 = SampleTex(_SourcePositionTex0, pos).xyz;
					float3 p1 = SampleTex(_SourcePositionTex1, pos).xyz;
					float3 v0 = SampleTex(_VelocityTex, pos).xyz;
					float3 v1 = (p1 - p0) * unity_DeltaTime.y;
					//unity_DeltaTime.y 暂停的时候是无穷大
					float3 cv = min((v0 + v1) * 0.5, FLT_MAX);
					return float4(cv, 0.0);
				}

				pos.y -= 1;
				float3 v = SampleTex(_VelocityTex, pos).xyz;
				return float4(v * _Drag, 0);
			}
			ENDHLSL
		}

		//5
		Pass
		{
			Name "UpdateOrthnorm"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment UpdateOrthnormFragment

			float4 UpdateOrthnormFragment(v2f IN):SV_Target
			{
				float2 uv = IN.uv;
				int2 pos = IN.pos.xy;

				int2 uv0 = int2(pos.x, pos.y - 2);
				uv0.y = max(0, uv0.y);
				int2 uv1 = int2(pos.x, pos.y - 1);
				uv1.y = max(0, uv1.y);
				int2 uv2 = int2(pos.x, pos.y + 2);
				uv2.y = min(_PositionTex_TexelSize.w - 1, uv2.y);

				// Use the parent normal vector from the previous frame.
				float4 b1 = SampleTex(_OrthnormTex, uv1);
				float3 ax = StereoInverseProjection(b1.zw);

				//tangent vector
				float3 p0 = SampleTex(_PositionTex, uv0).xyz;
				float3 p1 = SampleTex(_PositionTex, uv2).xyz;
				float3 az = p1 - p0;
				if (az.x == 0 && az.y == 0 && az.z == 0)
				{
					az = float3(1, 0, 0); //guard div by zero
				}

				// Reconstruct the orthonormal basis.
				float3 ay = normalize(cross(az, ax));
				ax = normalize(cross(ay, az));

				// Twisting
				//越向下 弯曲越大
				float tw = frac(uv.x * 327.7289) * (1 - uv.y) * 0.2;
				ax = normalize(ax + ay * tw);

				return float4(StereoProjection(ay), StereoProjection(ax));
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
				int2 uv = int2(IN.pos.x, 0);
				float3 pos = SampleTex(_SourcePositionTex1, uv).rgb;

				//a far point and random life
				//是可以存在负数的
				o.pos = float4(pos, 0);
				o.vel = 0;
				o.orth = 0;
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

			//MRT支持不同尺寸的RT,但是渲染区域会是最小的图片
			//https://stackoverflow.com/questions/18678604/multiple-render-targets-in-one-fbo-with-different-size-textures
			outMRT UpdateMRTFragment(v2f IN)
			{
				outMRT o;

				float2 uv = IN.uv;
				int2 pos = int2(IN.pos.xy);


				if (pos.y == 0)
				{
					// The first row: calculate the vertex velocity.
					// Get the average with the previous frame for low-pass filtering.
					float3 p0 = SampleTex(_SourcePositionTex0, pos).xyz;
					float3 p1 = SampleTex(_SourcePositionTex1, pos).xyz;
					float3 v0 = SampleTex(_VelocityTex, pos).xyz;
					float3 v1 = (p1 - p0) * unity_DeltaTime.y;
					//unity_DeltaTime.y 暂停的时候是无穷大
					float3 cv = min((v0 + v1) * 0.5, FLT_MAX);
					o.vel = float4(cv, 0.0);
					o.pos = float4(p1, 0);
				}
				else
				{
					int2 vpos = int2(pos.x, pos.y - 1);

					float3 v = SampleTex(_VelocityTex, vpos).xyz;
					o.vel = float4(v * _Drag, 0);

					float3 p = SampleTex(_PositionTex, vpos);
					float lv = length(o.vel);
					if (lv > 0)
					{
						p += o.vel.xyz * (min(lv, _SpeedLimit) / lv) * unity_DeltaTime.x;
					}
					o.pos = float4(p, 0);
				}


				//本来这个写pass要单独执行  因为现在用prev是错误的结果
				//但是为了性能 还是将就把   反正看不出大差别
				//orth
				//-------------------------------
				int2 uv0 = int2(pos.x, pos.y - 2);
				uv0.y = max(0, uv0.y);
				int2 uv1 = int2(pos.x, pos.y - 1);
				uv1.y = max(0, uv1.y);
				int2 uv2 = int2(pos.x, pos.y + 2);
				uv2.y = min(_PositionTex_TexelSize.w - 1, uv2.y);

				// Use the parent normal vector from the previous frame.
				float4 b1 = SampleTex(_OrthnormTex, uv1);
				float3 ax = StereoInverseProjection(b1.zw);

				//tangent vector
				float3 p0 = SampleTex(_PositionTex, uv0);
				float3 p1 = SampleTex(_PositionTex, uv2);
				float3 az = p1 - p0;
				if (az.x == 0 && az.y == 0 && az.z == 0)
				{
					az = float3(1, 0, 0); //guard div by zero
				}

				// Reconstruct the orthonormal basis.
				float3 ay = normalize(cross(az, ax));
				ax = normalize(cross(ay, az));

				// Twisting
				//越向下 弯曲越大
				float tw = frac(uv.x * 327.7289) * (1 - uv.y) * 0.2;
				ax = normalize(ax + ay * tw);

				o.orth = float4(StereoProjection(ay), StereoProjection(ax));

				return o;
			}
			ENDHLSL
		}
	}
}