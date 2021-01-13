#ifndef __OUTLINE_OBJECT_INCLUDE__
	#define __OUTLINE_OBJECT_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	float4 _CameraDepthTexture_TexelSize;	//这个是没有定义的
	
	#ifdef _OUTLINE_ALPHA_COMPARE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
	#endif
	
	#ifdef MY_DEPTH_NORMAL
		
		TEXTURE2D(_CameraDepthNormalsTexture);
		SAMPLER(sampler_CameraDepthNormalsTexture);
		
		// 加密解密代码 都在UnityCG.cginc
		inline float2 EncodeFloatRG(float v)
		{
			float2 kEncodeMul = float2(1.0, 255.0);
			float kEncodeBit = 1.0 / 255.0;
			float2 enc = kEncodeMul * v;
			enc = frac(enc);
			enc.x -= enc.y * kEncodeBit;
			return enc;
		}
		
		inline float DecodeFloatRG(float2 enc)
		{
			float2 kDecodeDot = float2(1.0, 1 / 255.0);
			return dot(enc, kDecodeDot);
		}
		
		inline float2 EncodeViewNormalStereo(float3 n)
		{
			float kScale = 1.7777;
			float2 enc;
			enc = n.xy / (n.z + 1);
			enc /= kScale;
			enc = enc * 0.5 + 0.5;
			return enc;
		}
		
		inline float3 DecodeViewNormalStereo(float4 enc)
		{
			float kScale = 1.7777;
			float3 nn = enc.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
			float g = 2.0 / dot(nn.xyz, nn.xyz);
			float3 n;
			n.xy = g * nn.xy;
			n.z = g - 1;
			return n;
		}
		
		inline float4 EncodeDepthNormal(float depth, float3 normal)
		{
			float4 enc;
			enc.xy = EncodeViewNormalStereo(normal);
			enc.zw = EncodeFloatRG(depth);
			return enc;
		}
		
		
		inline void DecodeDepthNormal(float4 enc, out float depth, out float3 normal)
		{
			depth = DecodeFloatRG(enc.zw);
			normal = DecodeViewNormalStereo(enc);
		}
		
	#else
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
	#endif
	
	inline float3 SampleDepthNormal(float2 uv)
	{
		#ifdef MY_DEPTH_NORMAL
			return DecodeViewNormalStereo(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv));
		#else
			return SampleSceneNormals(uv);
		#endif
	}
	
	#ifdef _OUTLINE_ALPHA_COMPARE
		//UNITY 提供的是 返回 float3  rgb
		inline float4 MySampleSceneColor(float2 uv)
		{
			return SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, UnityStereoTransformScreenSpaceTex(uv));
		}
	#endif
	
	#ifdef _OUTLINE_ALPHA_COMPARE
		void OutlineObject_float(float2 uv, float outlineThickness, float depthSensitivity, float normalSensitivity, out float outline, out float sceneDepth, out float4 originalColor, out float alphaDetail)
	#else
		void OutlineObject_float(float2 uv, float outlineThickness, float depthSensitivity, float normalSensitivity, out float outline, out float sceneDepth)
	#endif
	{
		#ifdef _OUTLINE_ALPHA_COMPARE
			originalColor = MySampleSceneColor(uv);
		#endif
		
		//Scene View 下 sceneDepth 可能有BUG
		sceneDepth = SampleSceneDepth(uv);
		
		float halfScaleFloor = floor(outlineThickness * 0.5);
		float halfScaleCeil = ceil(outlineThickness * 0.5);
		
		float2 uvSamples[4];
		float depthSamples[4];
		float3 normalSamples[4];
		#ifdef _OUTLINE_ALPHA_COMPARE
			float4 colorSamples[4];
		#endif
		
		//不是很规则的边缘判断
		float2 offsetStep = float2(_CameraDepthTexture_TexelSize.x, _CameraDepthTexture_TexelSize.y);
		uvSamples[0] = uv - offsetStep * halfScaleFloor;
		uvSamples[1] = uv + offsetStep * halfScaleCeil;
		uvSamples[2] = uv + offsetStep * float2(halfScaleCeil, -halfScaleFloor);
		uvSamples[3] = uv + offsetStep * float2(-halfScaleFloor, halfScaleCeil);
		
		UNITY_UNROLL
		for (int i = 0; i < 4; i ++)
		{
			depthSamples[i] = SampleSceneDepth(uvSamples[i]);
			normalSamples[i] = SampleDepthNormal(uvSamples[i]);
			#ifdef _OUTLINE_ALPHA_COMPARE
				colorSamples[i] = MySampleSceneColor(uvSamples[i]);
			#endif
		}
		
		//Depth
		float depthFiniteDifference0 = depthSamples[1] - depthSamples[0];
		float depthFiniteDifference1 = depthSamples[3] - depthSamples[2];
		float edgeDepth = sqrt(depthFiniteDifference0 * depthFiniteDifference0 + depthFiniteDifference1 * depthFiniteDifference1) * 100;
		float depthThreshold = (1 / depthSensitivity) * sceneDepth;//但是会根据sceneDepth而变化 可以考虑删除
		edgeDepth = edgeDepth > depthThreshold?1: 0;
		
		//Normals
		float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
		float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
		float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
		edgeNormal = edgeNormal > (1 / normalSensitivity) ? 1: 0;
		
		#ifdef _OUTLINE_ALPHA_COMPARE
			//Alpha
			float4 colorFiniteDifference0 = colorSamples[1] - colorSamples[0];
			float4 colorFiniteDifference1 = colorSamples[3] - colorSamples[2];
			alphaDetail = step(0.001, sqrt(dot(colorFiniteDifference0.a, colorFiniteDifference0.a) + dot(colorFiniteDifference1.a, colorFiniteDifference1.a)));
			alphaDetail = clamp(alphaDetail, 0, 1);
		#endif
		
		outline = clamp(max(edgeDepth, edgeNormal), 0, 1);
	}
	
	float3 Outlines(float2 screenPosition, float outlineThickness, float outlineDepthSensitivity, float outlineNormalSensitivity)
	{
		float outline;
		float sceneDepth;
		#ifdef _OUTLINE_ALPHA_COMPARE
			float4 originalColor;
			float alphaDetail;
			OutlineObject_float(screenPosition, outlineThickness, outlineDepthSensitivity, outlineNormalSensitivity, outline, sceneDepth, originalColor, alphaDetail);
		#else
			OutlineObject_float(screenPosition, outlineThickness, outlineDepthSensitivity, outlineNormalSensitivity, outline, sceneDepth);
		#endif
		float3 outlineColor = float3(1, 1, 1);
		float3 normalColor = float3(0, 0, 0);
		float3 finalColor = lerp(outlineColor, normalColor, outline);
		return finalColor;
	}
	
	
#endif