#ifndef __MYCARTOONPBR_INCLUDE__
	#define __MYCARTOONPBR_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	
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
	
	half4 MyFragmentPBR(InputData inputData, SurfaceData surfaceData)
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
	
#endif