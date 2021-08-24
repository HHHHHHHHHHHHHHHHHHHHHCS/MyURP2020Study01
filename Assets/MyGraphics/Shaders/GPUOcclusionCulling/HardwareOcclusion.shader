Shader "GPUOcclusionCulling/HardwareOcclusion"
{
	Properties
	{
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Transparent" "Queue" = "Transparent"
		}

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			Cull Off
			ZTest Off
			
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


			struct a2v
			{
				float4 vertex:POSITION;
				uint id:SV_VertexID;
			};

			struct v2f
			{
				float4 pos :SV_POSITION;
				uint instance:TEXCOORD0;
			};

			//https://gamedev.net/forums/topic/672525-writing-to-uav-buffer/5257474/
			//RWStructuredBuffer  需要 target 5.0
			RWStructuredBuffer<float4> _Writer;
			StructuredBuffer<float4> _Reader;
			int _Debug;

			v2f vert(a2v IN)
			{
				v2f o;

				float4 wpos = _Reader[IN.id];

				o.instance = wpos.w;
				o.pos = mul(UNITY_MATRIX_VP, float4(wpos.xyz, 1.0));

				return o;
			}

			half4 frag(v2f IN) : SV_TARGET
			{
				_Writer[IN.instance] = IN.pos;
				return half4(0.0, 0.0, 1.0, 0.2 * _Debug);
			}
			ENDHLSL
		}
	}
}