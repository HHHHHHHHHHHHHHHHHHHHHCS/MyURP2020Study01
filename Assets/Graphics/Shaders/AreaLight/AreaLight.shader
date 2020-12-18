Shader "MyRP/AreaLight/AreaLight"
{
	//TODO:
	
	Properties
	{
		_MainTex ("Texture", 2D) = "white" { }
	}
	
	HLSLINCLUDE
	
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	
	// #define AREA_LIGHT_ENABLE_DIFFUSE 1
	
	// #if AREA_LIGHT_SHADOWS
	// 	#include "AreaLightShadows.hlsl"
	// #endif
	// #include "AreaLighting.hlsl"
	
	struct a2v
	{
		float4 vertex: POSITION;
		float2 uv: TEXCOORD0;
	};
	
	struct v2f
	{
		float4 pos: SV_POSITION;
		float2 uv: TEXCOORD0;
		float3 ray: TEXCOORD1;
	};
	
	TEXTURE2D_X(_CameraGBufferTexture0);
	SAMPLER(sampler_CameraGBufferTexture0);
	TEXTURE2D_X(_CameraGBufferTexture1);
	SAMPLER(sampler_CameraGBufferTexture1);
	TEXTURE2D_X(_CameraGBufferTexture2);
	SAMPLER(sampler_CameraGBufferTexture2);
	
	
	
	void DeferredCalculateLightParams(
		float3 ray, float4 screenPos,
		out float3 outWPos, out float2 outUV)
	{
		//_ProjectionParams.z = far plane
		//让 z = 1 ,  xy限制在[-1,1] 因为z基本最大
		float3 ndc = ray / ray.z * _ProjectionParams.z ;
		float2 uv = screenPos.xy / screenPos.w;//screenpos 齐次对齐
		
		float depth = SampleSceneDepth(uv);
		depth = Linear01Depth(depth, _ZBufferParams);
		float4 vpos = float4(ndc * depth, 1);
		float3 wpos = mul(unity_CameraToWorld, vpos).xyz;
		
		outWPos = wpos;
		outUV = uv;
	}
	
	half4 CalculateLightDeferred(float3 ray, float4 screenPos)
	{
		float3 worldPos;
		float2 uv;
		DeferredCalculateLightParams(ray, screenPos, worldPos, uv);
		
		//TODO:GBuffer->forward urp
		// half4 gbuffer0 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture0, sampler_CameraGBufferTexture0, uv);
		// half4 gbuffer1 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture1, sampler_CameraGBufferTexture1, uv);
		// half4 gbuffer2 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv);
		
		half3 baseColor = 1;//gbuffer0.rgb;
		half3 specColor = 1;//gbuffer1.rgb;
		half oneMinusRoughness = 0.5;//gbuffer1.a;
		half3 normalWorld = 0;//normalize(gbuffer2.rgb * 2 - 1);
		
		Light mainLight = GetMainLight();
		
		float3 col = CalculateLight(worldPos, baseColor, specColor, oneMinusRoughness, normalWorld,
		mainLight.direction, mainLight.color).rgb;
		
		return float4(col, 1.0);
	}
	
	v2f vert(a2v i)
	{
		v2f o = (v2f)0;
		o.pos = UnityObjectToClipPos(i.vertex);
		o.uv = ComputeScreenPos(o.pos);
		o.ray = UnityObjectToViewPos(i.vertex) * float3(-1, -1, 1);//view空间需要翻转下(左右手坐标系互换)
		return o;
	}
	
	
	half4 frag(v2f i): SV_TARGET
	{
		return CalculateLightDeferred(i.ray, i.screenPos);
	}
	
	
	ENDHLSL
	
	SubShader
	{
		//Queue 需要后面渲染
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry+1" }
		
		Fog
		{
			Mode Off
		}
		ZWrite Off
		Blend One One
		Cull Front
		ZTest Always
		
		//have shadows
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			//#define AREA_LIGHT_SHADOWS 1
			
			ENDHLSL
			
		}
		
		//no shadows
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			//#define AREA_LIGHT_SHADOWS 0
			
			ENDHLSL
			
		}
	}
}
