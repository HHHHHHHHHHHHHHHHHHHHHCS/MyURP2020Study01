Shader "MyRP/Skinner/GlitchKernels"
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
	TEXTURE2D(_VelocityTex);

	float _VelocityScale;

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
				float3 pos = SampleTex(_SourcePositionTex1, uv).xyz;
				
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

				p += v * unity_DeltaTime.x;

				return float4(p, 0.0);
			}
			ENDHLSL
		}

		//3
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
					float3 v0 = (p1 - p0) * unity_DeltaTime.y * _VelocityScale;
					//unity_DeltaTime.y 暂停的时候是无穷大
					v0 = min(v0, FLT_MAX);
					return float4(v0, 0);
				}

				pos.y -= 1;
				float4 v = SampleTex(_VelocityTex, pos);
				return v;
			}
			ENDHLSL
		}
	}
}