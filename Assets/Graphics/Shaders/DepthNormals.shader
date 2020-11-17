Shader "MyRP/Cartoon/DepthNormals"
{
	Properties { }
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		
		Pass
		{
			Name "DepthNormals"
			Tags { "LightMode" = "DepthNormals" }
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#define MY_DEPTH_NORMAL
			
			#include "OutlineObject.hlsl"
			
			struct a2v
			{
				float4 vertex: POSITION;
				float3 normal: NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 pos: SV_POSITION;
				float4 normalZ: TEXCOORD0;
			};
			
			
			v2f vert(a2v v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				
				v2f o;
				float4 positionWS = mul(GetObjectToWorldMatrix(), v.vertex);
				float4 positionVS = mul(GetWorldToViewMatrix(), positionWS);
				float4 positionCS = mul(GetViewToHClipMatrix(), positionVS);
				
				o.pos = positionCS;
				o.normalZ.xyz = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal));
				o.normalZ.w = - (positionVS.z * _ProjectionParams.w);
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				return EncodeDepthNormal(i.normalZ.w, i.normalZ.xyz);
			}
			ENDHLSL
			
		}
	}
}
