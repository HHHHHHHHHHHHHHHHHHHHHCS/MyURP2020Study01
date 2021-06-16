//https://github.com/Sorumi/UnityRayTracingGem
Shader "MyRP/RayTracingGem//RayTracingGem"
{
	Properties
	{
	}
	SubShader
	{

		Pass
		{
			Cull Back

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				return o;
			}

			half4 frag(v2f IN, half facing : VFACE) : SV_Target
			{
				if (facing > 0)
				{
					return half4(1, 0, 0, 1);
				}
				else
				{
					return 1;
				}
			}
			ENDHLSL
		}
	}
}