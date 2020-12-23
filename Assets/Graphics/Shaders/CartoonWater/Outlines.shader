Shader "MyRP/CartoonWater/Outlines"
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
	HLSLINCLUDE
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	CBUFFER_START(UnityPerMaterial)
	float _DepthSensitivity;
	float _NormalsSensitivity;
	float _Thickness;
	float _DepthFade;
	float _AngleFade;
	float _HorizonFade;
	float4 _HorizonColor;
	float4 _Color;
	float _DetailNoiseScale;
	float _DetailNoiseStep;
	CBUFFER_END
	
	ENDHLSL
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" /*"RenderPipeline"="UniversalPipeline"*/ }
		
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite Off
		
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			
			#pragma multi_compile _ MY_DEPTH_NORMAL
			#define _ALPHA_COMPARE 1
			
			#define _NORMALMAP 1
			// #define ATTRIBUTES_NEED_NORMAL
			// #define ATTRIBUTES_NEED_TANGENT
			// #define ATTRIBUTES_NEED_TEXCOORD1
			// #define VARYINGS_NEED_POSITION_WS
			// #define VARYINGS_NEED_NORMAL_WS
			// #define VARYINGS_NEED_TANGENT_WS
			// #define VARYINGS_NEED_VIEWDIRECTION_WS
			
			#include "../CartoonCommon/OutlineObject.hlsl"
			#include "../CartoonCommon/CommonFunction.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				float4 normal: NORMAL;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 normalWS: NORMAL;
				float3 positionWS: TEXCOORD0;
				float2 uv: TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.normalWS = TransformObjectToWorldNormal(v.normal.xyz);
				o.positionCS = TransformWorldToHClip(o.positionWS);
				o.screenUV = ComputeScreenPos(o.positionCS, _ProjectionParams.x);
				o.uv = v.uv;
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				
				
				//Outlines With Alpha Detail
				float outline;
				float sceneDepth;
				float4 originalColor;
				float alphaDetail;
				OutlineObject_float(i.screenUV, _Thickness, _DepthSensitivity, _NormalsSensitivity, out  outline, out  sceneDepth, out  originalColor, out  alphaDetail);
				
				//Detail Noise
				float noise = GradientNoise(i.uv, _DetailNoiseScale);
				noise = 1 - step(_DetailNoiseStep, noise) * alphaDetail;
				noise *= 1 - outline;
				float4 outlineColor = noise * originalColor + (1 - noise) * _Color;

				//Outline Fade
				//TODO:
				
				return col;
			}
			ENDHLSL
			
		}
	}
}
