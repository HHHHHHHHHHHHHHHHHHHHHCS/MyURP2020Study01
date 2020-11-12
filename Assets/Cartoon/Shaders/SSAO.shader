Shader "MyRP/Cartoon/SSAO"
{
	HLSLINCLUDE
	
	#pragma exclude_renderers d3d11_9x
	
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	half4 _ScaleBiasRt;
	
	struct a2v
	{
		float4 positionHCS: POSITION;
		float2 uv: TEXCOORD0;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};
	
	struct v2f
	{
		float4 positionCS: SV_POSITION;
		float2 uv: TEXCOORD0;
		UNITY_VERTEX_OUTPUT_STEREO
	};
	
	v2f vert(a2v v)
	{
		v2f o;
		UNITY_SETUP_INSTANCE_ID(v);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		
		//位置和UV 在Mesh 创建的时候已经被设置好了
		//翻转Y是因为 https://issuetracker.unity3d.com/issues/lwrp-depth-texture-flipy
		//Unity在非OpenGL平台和渲染到渲染纹理时翻转投影矩阵。
		//如果URP渲染为RT——翻转Y
		//如果URP不渲染为RT，也不使用OpenGL进行渲染——不翻转
		o.positionCS = float4(v.positionHCS.xyz, 1.0);
		o.positionCS.y *= _ScaleBiasRt.x;
		o.uv = v.uv;
		
		//添加一个small epsilon  避免法线重建时候出现问题
		o.uv += 1.0e-6;
		
		return o;
	}
	
	ENDHLSL
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
		Cull Off ZWrite Off ZTest Always
		
		// 0 - Occlusion estimation with CameraDepthTexture
		Pass
		{
			Name "SSAO_Occlusion"
			ZTest Always
			ZWrite Off
			Cull Off
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment SSAO
			#pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
			#pragma multi_compile_local _RECONSTRUCT_NORMAL_LOW _RECONSTRUCT_NORMAL_MEDIUM _RECONSTRUCT_NORMAL_HIGH
			#pragma multi_compile_local _ _ORTHOGRAPHIC
			#include "SSAO.hlsl"
			ENDHLSL
			
		}
		
		// 1 - Horizontal Blur
		Pass
		{
			Name "SSAO_HorizontalBlur"
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment HorizontalBlur
			#define BLUR_SAMPLE_CENTER_NORMAL
			#pragma multi_compile_local _ _ORTHOGRAPHIC
			#pragma multi_compile_local _SOURCE_DEPTH _SOURCE_DEPTH_NORMALS _SOURCE_GBUFFER
			#include "SSAO.hlsl"
			ENDHLSL
			
		}
		
		// 2 - Vertical Blur
		Pass
		{
			Name "SSAO_VerticalBlur"
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment VerticalBlur
			#include "SSAO.hlsl"
			ENDHLSL
			
		}
		
		// 3 - Final Blur
		Pass
		{
			Name "SSAO_FinalBlur"
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment FinalBlur
			#include "SSAO.hlsl"
			ENDHLSL
			
		}
	}
}
