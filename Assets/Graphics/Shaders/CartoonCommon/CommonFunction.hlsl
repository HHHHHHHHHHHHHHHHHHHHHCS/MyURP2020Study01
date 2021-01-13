#ifndef __COMMON_FUNCTION_INCLUDE__
	#define __COMMON_FUNCTION_INCLUDE__
	
	float4 ComputeScreenPos(float4 pos, float projectionSign)
	{
		float4 o = pos * 0.5;
		o.xy = float2(o.x, o.y * projectionSign) + o.w;
		o.zw = pos.zw;
		return o;
	}
	
	
	bool IsGammaSpace()
	{
		#ifdef UNITY_COLORSPACE_GAMMA
			return true;
		#else
			return false;
		#endif
	}
	
	
	inline float2 GradientNoiseDir(float2 p)
	{
		p = p % 289;
		
		float x = float(34 * p.x + 1) * p.x % 289 + p.y;
		x = (34 * x + 1) * x % 289;
		x = frac(x / 41) * 2 - 1;
		return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
	}
	
	float GradientNoise(float2 uv, float scale)
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
	
#endif