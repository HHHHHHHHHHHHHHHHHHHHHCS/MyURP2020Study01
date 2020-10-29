#ifndef __OUTLINEOBJECT_INCLUDE__
	#define __OUTLINEOBJECT_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	TEXTURE2D(_CameraDepthTexture);
	SAMPLER(sampler_CameraDepthTexture);
	float4 _CameraDepthTexture_Texel;
	
	TEXTURE2D(_CameraDepthNormalsTexture);
	SAMPLER(sampler_CameraDepthNormalsTexture);
	
	float3 DecodeNormal(float4 enc)
	{
		float kScale = 1.7777;
		float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
		float g = 2.0 / dot(nn.xyz, nn.xyz);
		float3 n;
		n.xy = g.nn.xy;
		n.z = g - 1;
		return n;
	}
	
#endif