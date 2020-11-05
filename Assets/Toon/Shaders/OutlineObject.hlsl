#ifndef __OUTLINEOBJECT_INCLUDE__
	#define __OUTLINEOBJECT_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	TEXTURE2D(_CameraDepthTexture);
	SAMPLER(sampler_CameraDepthTexture);
	float4 _CameraDepthTexture_TexelSize;
	
	TEXTURE2D(_CameraDepthNormalsTexture);
	SAMPLER(sampler_CameraDepthNormalsTexture);
	
	// 加密代码  在UnityCG.cginc
	/*
	inline float2 EncodeViewNormalStereo(float3 n)
	{
		float kScale = 1.7777;
		float2 enc;
		enc = n.xy / (n.z + 1);
		enc /= kScale;
		enc = enc * 0.5 + 0.5;
		return enc;
	}
	*/

	//解法线代码
	float3 DecodeNormal(float4 enc)
	{
		float kScale = 1.7777;
		float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
		float g = 2.0 / dot(nn.xyz, nn.xyz);
		float3 n;
		n.xy = g * nn.xy;
		n.z = g - 1;
		return n;
	}
	
	void OutlineObject_float(float2 uv, float outlineThickness, float depthSensitivity, float normalSensitivity, out float outline, out float sceneDepth)
	{
		sceneDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
		
		float halfScaleFloor = floor(outlineThickness * 0.5);
		float halfScaleCeil = ceil(outlineThickness * 0.5);
		
		float2 uvSamples[4];
		float depthSamples[4];
		float3 normalSamples[4];
		
		uvSamples[0] = uv - float2(_CameraDepthTexture_TexelSize.x, _CameraDepthTexture_TexelSize.y) * halfScaleFloor;
		uvSamples[1] = uv + float2(_CameraDepthTexture_TexelSize.x, _CameraDepthTexture_TexelSize.y) * halfScaleCeil;
		uvSamples[2] = uv + float2(_CameraDepthTexture_TexelSize.x * halfScaleCeil, -_CameraDepthTexture_TexelSize.y * halfScaleFloor);
		uvSamples[3] = uv + float2(-_CameraDepthTexture_TexelSize.x * halfScaleFloor, _CameraDepthTexture_TexelSize.y * halfScaleCeil);
		
		for (int i = 0; i < 4; i ++)
		{
			depthSamples[i] = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[i]).r;
			normalSamples[i] = DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i]));
		}
		
		//Depth
		float depthFiniteDifference0 = depthSamples[1] - depthSamples[0];
		float depthFiniteDifference1 = depthSamples[3] - depthSamples[2];
		float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100;
		float depthThreshold = (1 / depthSensitivity) * sceneDepth;//depthSamples[0];
		edgeDepth = edgeDepth > depthThreshold?1: 0;
		
		//Normals
		float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
		float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
		float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
		edgeNormal = edgeNormal > (1 / normalSensitivity) ? 1: 0;
		
		float edge = max(edgeDepth, edgeNormal);
		outline = edge;
	}
	
#endif