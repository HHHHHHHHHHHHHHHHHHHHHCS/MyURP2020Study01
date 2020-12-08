#ifndef __MYCARTOONPBR_INCLUDE__
	#define __MYCARTOONPBR_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	
	#include "CommonFunction.hlsl"
	#include "MainLight.hlsl"
	#include "OutlineObject.hlsl"
	
	struct MyInputData
	{
		float3  positionWS;
		half3   normalWS;
		half3   viewDirectionWS;
		float4  shadowCoord;
		half    fogCoord;
		half3   vertexLighting;
		half3   bakedGI;
		float2  normalizedScreenSpaceUV;
	};
	
	struct MySurfaceData
	{
		half3 albedo;
		half3 specular;
		half  metallic;
		half  smoothness;
		half3 normalTS;
		half3 emission;
		half  occlusion;
		half  alpha;
		half  clearCoatMask;
		half  clearCoatSmoothness;
	};
	
	// 已经定义在Library\PackageCache\com.unity.render-pipelines.universal@10.0.0-preview.26\ShaderLibrary\Lighting.hlsl
	// TEXTURE2D(_ScreenSpaceOcclusionTexture);
	// SAMPLER(sampler_ScreenSpaceOcclusionTexture);
	
	half4 MyFragmentPBR(MyInputData inputData, MySurfaceData surfaceData)
	{
		#ifdef _SPECULARHIGHLIGHTS_OFF
			bool specularHighlightsOff = true;
		#else
			bool specularHighlightsOff = false;
		#endif
		
		BRDFData brdfData;
		
		// NOTE: can modify alpha
		InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);
		
		BRDFData brdfDataClearCoat = (BRDFData)0;
		#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
			// base brdfData is modified here, rely on the compiler to eliminate dead computation by InitializeBRDFData()
				InitializeBRDFDataClearCoat(surfaceData.clearCoatMask, surfaceData.clearCoatSmoothness, brdfData, brdfDataClearCoat);
		#endif
		
		Light mainLight = GetMainLight(inputData.shadowCoord);
		
		#if defined(_SCREEN_SPACE_OCCLUSION)
			AmbientOcclusionFactor aoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
			mainLight.color *= aoFactor.directAmbientOcclusion;
			surfaceData.occlusion = min(surfaceData.occlusion, aoFactor.indirectAmbientOcclusion);
		#endif
		
		MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));
		half3 color = GlobalIllumination(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
		inputData.bakedGI, surfaceData.occlusion,
		inputData.normalWS, inputData.viewDirectionWS);
		color += LightingPhysicallyBased(brdfData, brdfDataClearCoat,
		mainLight,
		inputData.normalWS, inputData.viewDirectionWS,
		surfaceData.clearCoatMask, specularHighlightsOff);
		
		#ifdef _ADDITIONAL_LIGHTS
			uint pixelLightCount = GetAdditionalLightsCount();
			for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++ lightIndex)
			{
				Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
				#if defined(_SCREEN_SPACE_OCCLUSION)
					light.color *= aoFactor.directAmbientOcclusion;
				#endif
				color += LightingPhysicallyBased(brdfData, brdfDataClearCoat,
				light,
				inputData.normalWS, inputData.viewDirectionWS,
				surfaceData.clearCoatMask, specularHighlightsOff);
			}
		#endif
		
		#ifdef _ADDITIONAL_LIGHTS_VERTEX
			color += inputData.vertexLighting * brdfData.diffuse;
		#endif
		
		color += surfaceData.emission;
		
		return half4(color, surfaceData.alpha);
	}
	
	float4 CalcPBRColor(MyInputData inputData, MySurfaceData surfaceData)
	{
		float4 color = MyFragmentPBR(inputData, surfaceData);
		color.rgb = MixFog(color.rgb, inputData.fogCoord);
		
		return color;
	}
	
	inline float AmbientOcclusion(float2 screenPosition)
	{
		float ao = 1;
		#if defined(_SCREEN_SPACE_OCCLUSION)
			ao = SAMPLE_TEXTURE2D(_ScreenSpaceOcclusionTexture, sampler_ScreenSpaceOcclusionTexture, screenPosition).r;
		#endif
		return ao;
	}
	
	float3 ToonLighting(float3 positionWS, float3 normalWS, float3 viewDirectionWS, float toonColorOffset, float toonColorSpread, float toonHighlightIntensity, float toonColorSteps, float3 toonShadedColor, float3 toonLitColor, float3 toonSpecularColor)
	{
		half3 lightDirection;
		half3 lightColor;
		half distanceAtten;
		half shadowAtten;
		MainLight_half(positionWS, lightDirection, lightColor, distanceAtten, shadowAtten);
		
		//------
		float lerpVal = saturate(dot(normalWS, lightDirection)) * shadowAtten;
		lerpVal = smoothstep(toonColorOffset -toonColorSpread, toonColorOffset +toonColorSpread, lerpVal);
		float steps = toonColorSteps - 1;
		lerpVal = floor(lerpVal / (1 / steps)) * (1 / steps);
		
		//------
		float3 halfDir = normalize(lightDirection + viewDirectionWS);
		float d = dot(halfDir, normalWS);
		d = step(1 - toonHighlightIntensity, d);
		
		//------
		float3 finalColor = lerp(toonShadedColor, toonLitColor, lerpVal);
		finalColor = lerp(finalColor, toonSpecularColor, d);
		
		return finalColor;
	}
	
	
	
#endif