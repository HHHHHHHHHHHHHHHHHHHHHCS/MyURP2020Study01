Shader "MyRP/AreaLight/AreaLight"
{
	//TODO:
	
	Properties
	{
		_MainTex ("Texture", 2D) = "white" { }
	}
	
	HLSLINCLUDE
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	
	#define AREA_LIGHT_ENABLE_DIFFUSE 1
	
	#if AREA_LIGHT_SHADOWS
		#include "AreaLightShadows.hlsl"
	#endif
	#include "AreaLighting.hlsl"
	
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
		//ray.z 基本是1
		float3 ray = ray * _ProjectionParams.z / ray.z;
		float2 uv = uv.xy / uv.w;//screenpos 齐次对齐
		
		float depth = SampleSceneDepth(uv);
		depth = Linear01Depth(depth);
		float4 vpos = float4(i.ray * depth, 1);
		float3 wpos = mul(unity_CameraToWorld, vpos).xyz;
		
		outWPos = wpos;
		outUV = uv;
	}
	
	half4 CalculateLightDeferred(float3 ray, float4 screenPos)
	{
		float3 worldPos;
		float2 uv;
		DeferredCalculateLightParams(ray, screenPos, worldPos, uv);
		
		half4 gbuffer0 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture0, sampler_CameraGBufferTexture0, uv);
		half4 gbuffer1 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture1, sampler_CameraGBufferTexture1, uv);
		half4 gbuffer2 = SAMPLE_TEXTURE2D_X(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv);
		
		half3 baseColor = gbuffer0.rgb;
		half3 specColor = gbuffer1.rgb;
		half oneMinusRoughness = gbuffer1.a;
		half3 normalWorld = normalize(gbuffer2.rgb * 2 - 1);
		
		//TODO:GetMainLight()
		float3 col = CalculateLight(worldPos, baseColor, specColor, oneMinusRoughness, normalWorld,
		_LightPos.xyz, _LightColor.xyz).rgb;
		
		return float4(col, 1.0);
	}
	
	
	ENDHLSL
	
	SubShader
	{
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
			
			#define AREA_LIGHT_SHADOWS 1
			
			half4 frag(v2f i): SV_TARGET
			{
				return CalculateLightDeferred(i.ray, i.screenPos);
			}
			
			ENDHLSL
			
		}
		
		//no shadows
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#define AREA_LIGHT_SHADOWS 0
			
			half4 frag(v2f i): SV_TARGET
			{
				return CalculateLightDeferred(i.ray, i.screenPos);
			}
			
			ENDHLSL
			
		}
	}
}
