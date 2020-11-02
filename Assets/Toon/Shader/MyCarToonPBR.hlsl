#ifndef __MYCARTOONPBR_INCLUDE__
	#define __MYCARTOONPBR_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	

	
	struct Varyings
	{
		float4 positionCS: SV_POSITION;
		float3 positionWS;
		float3 normalWS;
		float4 tangentWS;
		float3 viewDirectionWS;
		#if defined(LIGHTMAP_ON)
			float2 lightmapUV;
		#endif
		#if !defined(LIGHTMAP_ON)
			float3 sh;
		#endif
		float4 fogFactorAndVertexLight;
		float4 shadowCoord;
		#if UNITY_ANY_INSTANCING_ENABLED
			uint instanceID: CUSTOM_INSTANCE_ID;
		#endif
		#if (defined(UNITY_STEREO_MULTIVIEW_ENABLED)) || (defined(UNITY_STEREO_INSTANCING_ENABLED) && (defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE)))
			uint stereoTargetEyeIndexAsBlendIdx0: BLENDINDICES0;
		#endif
		#if(defined(UNITY_STEREO_INSTANCING_ENABLED))
			uint stereoTargetEyeIndexAsRTArrayIdx: SV_RenderTargetArrayIndex;
		#endif
		#if defined(SHADER_STAGE_FRAGMENT) && defined(VARYINGS_NEED_CULLFACE)
			FRONT_FACE_TYPE cullFace: FRONT_FACE_SEMANTIC;
		#endif
	};
	
	struct SurfaceData
	{
		float3 baseColor;
		float3 normalTS;
		float3 emission;
		float metallic;
		float smoothness;
		float occlusion;
	};
	
	struct PBRData
	{
		float3 positionWS;
		half3 normalWS;
		half3 viewDirectionWS;
		float4 shadowCoord;
		half fogCoord;
		half3 vertexlighting;
		half3 bakeGI;
		float2 normalizedScreenSpaceUV;
	};
	
	PBRData SetupPBRData(float3 pos, float3 normal, float3)
	{
		
	}
	
	float4 CalcPBRColor(PBRData data, float4 baseColor, float metallic, float specular, float smoothness, float occlusion, float4 emission, float alpha)
	{
		
	}
	
#endif