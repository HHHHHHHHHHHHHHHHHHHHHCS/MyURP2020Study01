Shader "MyRP/AtmosphericScattering/RuntimeSkybox"
{
	Properties
	{
	}
	SubShader
	{
		Tags
		{
			"Queue"="Background" "RenderType"="Background" "PreviewType" = "Skybox" "RenderPipeline"="UniversalPipeline"
		}
		ZWrite Off
		Cull Off
		
		Pass
		{
			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#define _RENDERSUN 1
			#define SAMPLECOUNT_SKYBOX 64

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "InScattering.hlsl"


			struct a2v
			{
				float3 vertex:POSITION;
			};

			struct v2f
			{
				float4 positionCS:SV_POSITION;
				float3 positionOS:TEXCOORD0;
			};

			v2f vert(a2v IN)
			{
				v2f o = (v2f)0;
				o.positionCS = TransformObjectToHClip(IN.vertex);
				o.positionOS = IN.vertex;
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				return CalcInScattering(IN.positionOS);
			}
			
			ENDHLSL
		}
	}
}