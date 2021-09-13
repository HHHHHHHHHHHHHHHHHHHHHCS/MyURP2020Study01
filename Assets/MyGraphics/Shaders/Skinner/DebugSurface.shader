Shader "MyRP/Skinner/DebugSurface"
{
	Properties
	{

	}
	HLSLINCLUDE
	ENDHLSL
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry"
		}

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "SkinnerCommon.hlsl"

			struct a2v
			{
				uint vertexID : SV_VertexID;
			};

			struct v2f
			{
				float4 position : SV_POSITION;
				half3 color : TEXCOORD0;
			};

			TEXTURE2D(_DebugPrevPositionTex);
			TEXTURE2D(_DebugPositionTex);
			TEXTURE2D(_DebugNormalTex);
			TEXTURE2D(_DebugTangentTex);

			#define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)
			
			v2f vert(a2v IN)
			{
			    const float len = 0.05;

				int2 uv = int2(IN.vertexID/6, 0);

				float3 prevPos = SampleTex(_DebugPrevPositionTex, uv).xyz;
				float3 currPos = SampleTex(_DebugPositionTex, uv).xyz;
				float3 normal = SampleTex(_DebugNormalTex, uv).xyz;
				float3 tangent = SampleTex(_DebugTangentTex, uv).xyz;

				int index = IN.vertexID % 6;
				int isOne = IN.vertexID % 2;

				half3 color;

			    if (index<2)
			    {
			    	// float3 delta;
			    	// // Line group #0 (red) - Velocity vector
			    	// if(IsInf(unity_DeltaTime.y))
			    	// {
			    	// 	 delta = cross(normal,tangent);
			    	// }
			    	// else
			    	// {
				    //      delta = (currPos - prevPos) * unity_DeltaTime.y;
			    	// }
			    	float3 delta = (currPos - prevPos) * unity_DeltaTime.y;
			        currPos = currPos - delta * (isOne * len * 2);
			        color = lerp(half3(1, 0, 0), 0.5, isOne);
			    }
			    else if (index<4)
			    {
			        // Line group #1 (green) - Normal vector
			        currPos += normal * isOne * len;
			        color = lerp(half3(0, 1, 0), 0.5, isOne);
			    }
			    else
			    {
			        // Line group #2 (blue) - Tangent vector
			        currPos += tangent * isOne * len;
			        color = lerp(half3(0, 0, 1), 0.5, isOne);
			    }

			    v2f o;
			    o.position = TransformWorldToHClip(currPos);
			    o.color = color;
				
			    return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
			    return half4(IN.color, 1);
			}
			
			ENDHLSL
		}
	}
}