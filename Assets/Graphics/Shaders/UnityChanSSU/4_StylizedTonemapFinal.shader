Shader "MyRP/UnityChanSSU/4_StylizedTonemapFinal"
{
	Properties
	{
	}
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

			struct a2v
			{
				uint vertexID :SV_VertexID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				return 1;
			}
			ENDHLSL
		}
	}
}