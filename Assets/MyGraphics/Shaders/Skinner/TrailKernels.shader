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
	//是不会超过[0, w or h)的
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
				half3 pos = SampleTex(_SourcePositionTex1, uv);
				
				//a far point and random life
				//是可以存在负数的
				return float4(pos, UVRandom(IN.uv, 16) - 0.5);
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
				return FLT_EPS;
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

				float lv = max(length(v), FLT_EPS);
				v = v * min(lv, _SpeedLimit) / lv;

				p += v * unity_DeltaTime.x;

				return half4(p, 0);
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

				float2 uv0 = float2(pos.x, pos.y - 2);
				float2 uv1 = float2(pos.x, pos.y - 1);
				float2 uv2 = float2(pos.x, pos.y + 2);

				// Use the parent normal vector from the previous frame.
				half4 b1 = SampleTex(_OrthnormTex, uv1);
				half3 ax = StereoInverseProjection(b1.zw);

				//tangent vector
				float3 p0 = SampleTex(_PositionTex, uv0).xyz;
				float3 p1 = SampleTex(_PositionTex, uv2).xyz;
				half3 az = p1 - p0;
				if (az.x == 0 && az.y == 0 && az.z == 0)
				{
					az = half3(FLT_EPS, 0, 0); //guard div by zero
				}

				// Reconstruct the orthonormal basis.
				half3 ay = normalize(cross(az, ax));
				ax = normalize(cross(ay, az));

				// Twisting
				//越向下 弯曲越大
				half tw = frac(uv.x * 327.7289) * (1 - uv.y) * 0.2;
				ax = normalize(ax + ay * tw);

				return half4(StereoProjection(ay), StereoProjection(ax));
			}
			ENDHLSL
		}
	}
}