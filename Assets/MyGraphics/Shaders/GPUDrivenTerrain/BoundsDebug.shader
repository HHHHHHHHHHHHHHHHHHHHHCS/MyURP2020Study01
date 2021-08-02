Shader "MyRP/GPUDrivenTerrain/BoundsDebug"
{
	Properties
	{
	}
	SubShader
	{
		Tags
		{
			"RenderType"= "Opaque" "LightMode" = "UniversalForward"
		}

		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _ENABLE_MIP_DEBUG

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "CommonInput.hlsl"

			StructuredBuffer<BoundsDebug> _BoundsList;

			struct a2v
			{
				float4 vertex : POSITION;
				uint instanceID : SV_InstanceID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 color : TEXCOORD0;
			};

			v2f vert(a2v IN)
			{
				v2f o;
				float4 inVertex = IN.vertex;
				BoundsDebug boundsDebug = _BoundsList[IN.instanceID];
				Bounds bounds = boundsDebug.bounds;

				float3 center = (bounds.minPosition + bounds.maxPosition) * 0.5;

				float3 scale = (bounds.maxPosition - center) / 0.5;

				inVertex.xyz = inVertex.xyz * scale + center;

				float4 vertex = TransformObjectToHClip(inVertex.xyz);
				o.vertex = vertex;
				o.color = boundsDebug.color.rgb;
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half4 col = half4(IN.color, 1);
				return col;
			}
			ENDHLSL
		}
	}
}