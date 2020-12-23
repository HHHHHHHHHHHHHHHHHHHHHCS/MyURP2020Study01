#ifndef __MYCARTOONWATERPBR_INCLUDE__
	#define __MYCARTOONWATERPBR_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "../CartoonCommon/CommonFunction.hlsl"
	
	// 已经定义在Library\PackageCache\com.unity.render-pipelines.universal@10.0.0-preview.26\ShaderLibrary\Lighting.hlsl
	// TEXTURE2D(_ScreenSpaceOcclusionTexture);
	// SAMPLER(sampler_ScreenSpaceOcclusionTexture);
	
	
	inline float2 VoronoiRandomVector(float2 uv, float offset)
	{
		float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
		uv = frac(sin(mul(uv, m)));
		return float2(sin(uv.y * offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
	}
	
	float2 Voronoi(float2 uv, float angleOffset, float cellDensity)
	{
		float2 g = floor(uv * cellDensity);
		float2 f = frac(uv * cellDensity);
		float t = 8.0;
		float3 res = float3(8.0, 0.0, 0.0);
		float2 ret = float2(0, 0);
		
		
		for (int y = -1; y <= 1; y ++)
		{
			for (int x = -1; x <= 1; x ++)
			{
				float2 lattice = float2(x, y);
				float2 offset = VoronoiRandomVector(lattice + g, angleOffset);
				float d = distance(lattice + offset, f);
				
				if (d < res.x)
				{
					res = float3(d, offset.x, offset.y);
					ret = res.xy;
				}
			}
		}
		
		return ret;
	}
	
	float2 DetailAlpha(float2 uv0, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		float2 uv = uv0 * detailScale;
		
		float noise0 = GradientNoise(uv0, detailNoiseScale) * detailNoiseStrength;
		
		uv += noise0.xx;
		
		float noise1 = GradientNoise(uv0, 3) * detailDensity;
		
		return Voronoi(uv, 2, noise1);
	}
	
	inline float DetailAlphaX(float2 uv, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		return DetailAlpha(uv, detailScale, detailNoiseStrength, detailNoiseScale, detailDensity).x;
	}
	
	inline float DetailAlphaY(float2 uv, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		return DetailAlpha(uv, detailScale, detailNoiseStrength, detailNoiseScale, detailDensity).y;
	}
	
	
	#if defined(_PLANAR_REFLECTION)
		TEXTURE2D(_PlanarReflectionTexture);
		SAMPLER(sampler_PlanarReflectionTexture);
		
		float2 WaterDetailAlpha(float2 uv0, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
		{
			float2 uv = float2(uv0.x, uv0.y * 0.2);
			
			float noise0 = GradientNoise(uv0, detailNoiseScale) * detailNoiseStrength;
			
			uv += noise0.xx;
			
			return Voronoi(uv, 2, detailDensity).y;
		}
		
		float3 PlanarReflection(float3 positionWS, float2 screenPosition)
		{
			float2 temp = positionWS.xy + (_Time.y * 0.1).xx;
			float noise = GradientNoise(temp, 15);
			float2 uv = screenPosition + noise * 0.005;
			
			float3 col = SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, uv).rgb;
			return col;
		}
	#endif
	
	
#endif