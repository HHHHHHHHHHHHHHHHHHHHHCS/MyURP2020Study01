#ifndef __COMMONFUNCTION_INCLUDE__
	#define __COMMONFUNCTION_INCLUDE__
	
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
	
#endif