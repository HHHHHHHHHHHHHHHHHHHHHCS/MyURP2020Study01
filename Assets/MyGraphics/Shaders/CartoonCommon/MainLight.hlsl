#ifndef __MAIN_LIGHT_INCLUDE__
	#define __MAIN_LIGHT_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	//Lighting 要在Shadows上面 不然会出现丢失function
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
	
	
	void MainLight_half(float3 worldPos, out half3 direction, out half3 color, out half distanceAtten, out half shadowAtten)
	{
		direction = half3(0.5, 0.5, 0);
		color = half3(1, 1, 1);
		distanceAtten = 1;
		shadowAtten = 1;
		
		//它这里原来是用 float3 absoluteWorldSpacePosition = GetAbsolutePositionWS(input.positionWS);

		//URP正常是没有屏幕空间阴影的   #define SHADOWS_SCREEN 0
		#if SHADOWS_SCREEN
			//如果是屏幕空间阴影  则直接用屏幕空间xy当uv
			half4 clipPos = TransformWorldToHClip(worldPos);
			half4 shadowCoord = ComputeScreenPos(clipPos);
		#else
			//否则直接转换到平行光空间 需要宏 _MAIN_LIGHT_SHADOWS_CASCADE
			half4 shadowCoord = TransformWorldToShadowCoord(worldPos);
		#endif
		
		Light mainLight = GetMainLight(shadowCoord);
		direction = mainLight.direction;
		color = mainLight.color;
		distanceAtten = mainLight.distanceAttenuation;
		
		#if !defined(_MAIN_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
			shadowAtten = 1.0h;
		#endif
		
		#if SHADOWS_SCREEN
			shadowAtten = SampleScreenSpaceShadowmap(shadowCoord);
		#else
			ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
			half shadowStrength = GetMainLightShadowStrength();
			shadowAtten = SampleShadowmap(shadowCoord, TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
		#endif
	}
	
#endif