Shader "MyRP/Cartoon/Outlines"
{
	Properties
	{
		_DepthSensitivity ("Depth Sensitivity", Float) = 0.2
		_NormalsSensitivity ("Normals Sensitivity", Float) = 2
		_Thickness ("Thickness", Float) = 1
		_DepthFade ("Depth Fade", Float) = 0
		_AngleFade ("Angle Fade", Float) = 1
		_HorizonFade ("Horizon Fade", Range(0, 1)) = 0
		_HorizonColor ("Horizon Color", Color) = (0, 0, 0, 0)
		_Color ("Color", Color) = (1, 0, 0, 0)
		_DetailNoiseScale ("Detail Noise Scale", Float) = 2
		_DetailNoiseStep ("Detail Noise Step", Float) = 0.6
	}
	SubShader
	{
		Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }
		
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite On
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			// Pragmas
			// #pragma target 4.5
			// #pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma shader_feature _ _SAMPLE_GI
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			struct a2v
			{
				float3 positionOS: POSITION;
				float3 normalOS: NORMAL;
				float4 tangentOS: TANGENT;
				float4 uv0: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 positionWS: TEXCOORD0;
				float3 normalWS: NORMAL;
				float4 uv0: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.positionOS);
				o.normalWS = TransformObjectToWorldNormal(v.normalOS);
				o.uv0 = v.uv0;
				o.positionCS = TransformWorldToHClip(o.positionWS);
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);

				i.normalWS = normalize(i.normalWS);
				
				
				return col;
			}
			ENDHLSL
			
		}
	}
}
