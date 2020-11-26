#ifndef __MYCARTOONWATERPBR_INCLUDE__
	#define __MYCARTOONWATERPBR_INCLUDE__
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	
	// 已经定义在Library\PackageCache\com.unity.render-pipelines.universal@10.0.0-preview.26\ShaderLibrary\Lighting.hlsl
	// TEXTURE2D(_ScreenSpaceOcclusionTexture);
	// SAMPLER(sampler_ScreenSpaceOcclusionTexture);
	
	inline float2 GradientNoiseDir(float2 p)
	{
		p = p % 289;
		
		float x = float(34 * p.x + 1) * p.x % 289 + p.y;
		x = (34 * x + 1) * x % 289;
		x = frac(x / 41) * 2 - 1;
		return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
	}
	
	inline float GradientNoise(float2 uv, float scale)
	{
		float2 p = uv * scale;
		float2 ip = floor(p);
		float2 fp = frac(p);
		float d00 = dot(GradientNoiseDir(ip), fp);
		float d01 = dot(GradientNoiseDir(ip + float2(0, 1)), fp - float2(0, 1));
		float d10 = dot(GradientNoiseDir(ip + float2(1, 0)), fp - float2(1, 0));
		float d11 = dot(GradientNoiseDir(ip + float2(1, 1)), fp - float2(1, 1));
		fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
		return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
	}
	
	inline float2 VoronoiRandomVector(float2 uv, float offset)
	{
		float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
		uv = frac(sin(mul(uv, m)));
		return float2(sin(uv.y * offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
	}
	
	inline float2 Voronoi(float2 uv, float angleOffset, float cellDensity)
	{
		float2 g = floor(uv * cellDensity);
		float2 f = frac(uv * cellDensity);
		float t = 8.0;
		float3 res = float3(8.0, 0.0, 0.0);
		
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
				}
			}
		}
		
		return res.xy;
	}
	
	inline float2 DetailAlpha(float2 uv, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		float2 uv = uv0 * detailScale;
		
		float noise0 = GradientNoise(uv, detailNoiseScale) * detailNoiseStrength;
		
		uv += noise0.xx;
		
		float noise1 = GradientNoise(uv, 3) * detailDensity;
		
		return Voronoi(uv, 2, noise1, ret, cells);
	}
	
	inline float DetailAlphaX(float2 uv, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		return DetailAlpha(uv, detailScale, detailNoiseStrength, detailNoiseScale, detailDensity).x;
	}
	
	inline float DetailAlphaY(float2 uv, float2 detailScale, float detailNoiseStrength, float detailNoiseScale, float detailDensity)
	{
		return DetailAlpha(uv, detailScale, detailNoiseStrength, detailNoiseScale, detailDensity).y;
	}
	
	
	float AmbientOcclusion(float2 screenPosition)
	{
		float ao = 1;
		#if defined(_SCREEN_SPACE_OCCLUSION)
			ao = SAMPLE_TEXTURE2D(_ScreenSpaceOcclusionTexture, sampler_ScreenSpaceOcclusionTexture, screenPosition).r;
		#endif
		return ao;
	}
	
	
	float3 ToonLighting(float3 positionWS, float3 normalWS, float3 viewDirectionWS, float toonColorOffset, float toonColorSpread, float toonHighlightIntensity, float toonColorSteps, float3 toonShadedColor, float3 toonLitColor, float3 toonSpecularColor)
	{
		
	}
	
#endif