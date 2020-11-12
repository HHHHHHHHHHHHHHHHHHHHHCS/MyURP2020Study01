#ifndef __SSAO_INCLUDE__
	#define __SSAO_INCLUDE__
	
	// Includes
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
	//#include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
	
	
	// Textures & Samplers
	TEXTURE2D_X(_BaseMap);
	TEXTURE2D_X(_ScreenSpaceOcclusionTexture);
	
	SAMPLER(sampler_BaseMap);
	SAMPLER(sampler_ScreenSpaceOcclusionTexture);
	
	// Params
	float4 _BlurOffset;
	float4 _SSAOParams;
	float4 _BaseMap_TexelSize;
	float4 _CameraDepthTexture_TexelSize;
	
	// SSAO Settings
	#define INTENSITY _SSAOParams.x
	#define RADIUS _SSAOParams.y
	#define DOWNSAMPLE _SSAOParams.z
	
	// GLES2: In many cases, dynamic looping is not supported.
	#if defined(SHADER_API_GLES) && !defined(SHADER_API_GLES3)
		#define SAMPLE_COUNT 3
	#else
		#define SAMPLE_COUNT _SSAOParams.w
	#endif
	
	// Function defines
	
	// scaledCameraHeight = pixelRect.height * cameraData.renderScale
	// x : scaledCameraWidth | y : scaledCameraHeight | z : 1.0f + 1.0f / scaledCameraWidth | w : 1.0f + 1.0f / scaledCameraHeight
	#define SCREEN_PARAMS        GetScaledScreenParams()
	#define SAMPLE_BASEMAP(uv)   SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv));
	#define SAMPLE_BASEMAP_R(uv) SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv)).r;
	
	// Constants
	// 遮挡对比度的最小值  很少用到
	static const float kContrast = 0.6;
	
	// 几何过滤器
	static const float kGeometryCoeff = 0.8;
	
	// AO的估计值，起抑制作用
	static const float kBeta = 0.002;
	
	// 防止向下溢出
	#define EPSILON         1.0e-4
	
	inline float4 PackAONormal(float ao, float3 n)
	{
		return float4(ao, n * 0.5 + 0.5);
	}
	
	inline float3 GetPackedNormal(float4 p)
	{
		return p.gba * 2.0 - 1.0;
	}
	
	inline float GetPackedAO(float4 p)
	{
		return p.r;
	}
	
	/*
	//Library\PackageCache\com.unity.render-pipelines.core@10.0.0-preview.30\ShaderLibrary\Color.hlsl
	//这种写法 能很好的处理值过小  的问题
	real LinearToSRGB(real c)
	{
		real sRGBLo = c * 12.92;
		real sRGBHi = (PositivePow(c, 1.0 / 2.4) * 1.055) - 0.055;
		real sRGB = (c <= 0.0031308) ? sRGBLo: sRGBHi;
		return sRGB;
	}
	*/
	
	inline float EncodeAO(float x)
	{
		#if UNITY_COLORSPACE_GAMMA
			return 1.0 - max(LinearToSRGB(1.0 - saturate(x)), 0.0);
		#else
			return x;
		#endif
	}
	
	inline float CompareNormal(float3 d1, float3 d2)
	{
		return smoothstep(kGeometryCoeff, 1.0, dot(d1, d2));
	}
	
	inline float2 GetScreenSpacePosition(float2 uv)
	{
		return uv * SCREEN_PARAMS.xy * DOWNSAMPLE;
	}
	
	inline float2 CosSin(float theta)
	{
		float sn, cs;
		sincos(theta, sn, cs);
		return float2(cs, sn);
	}
	
	inline float UVRandom(float2 u, float v)
	{
		float f = dot(float2(12.9898, 78.233), float2(u, v));
		return frac(43758, 5453 * sin(f));
	}
	
	/*
	//Library\PackageCache\com.unity.render-pipelines.core@10.0.0-preview.30\ShaderLibrary\Random.hlsl
	float InterleavedGradientNoise(float2 pixCoord, int frameCount)
	{
		const float3 magic = float3(0.06711056f, 0.00583715f, 52.9829189f);
		float2 frameMagicScale = float2(2.083f, 4.867f);
		pixCoord += frameCount * frameMagicScale;
		return frac(magic.z * frac(dot(pixCoord, magic.xy)));
	}
	*/
	
	//随机采样点
	float3 PickSamplePoint(float2 uv, float randAddon, int index)
	{
		float2 positionSS = GetScreenSpacePosition(uv);
		float gn = InterleaveGradientNoise(positionSS, index);
		float u = frac(UVRandom(0.0, index + randAddon) + gn) * 2.0 - 1.0;
		float theta = (UVRandom(1.0, index + randAddon) + gn) * TWO_PI;
		return float3(CosSin(theta) * sqrt(1.0 - u * u), u);
	}
	
	/*
	//Library\PackageCache\com.unity.render-pipelines.core@10.0.0-preview.30\ShaderLibrary\Common.hlsl
	float LinearEyeDepth(float depth, float4 zBufferParam)
	{
		return 1.0 / (zBufferParam.z * depth + zBufferParam.w);
	}
	*/
	
	float RawToLinearDepth(float rawDepth)
	{
		#if defined(_ORTHOGRAPHIC)
			//因为是非线性   所以要反算
			#if UNITY_REVERSED_Z
				return((_ProjectionParams.z - _ProjectionParams.y) * (1.0 - rawDepth) + _ProjectionParams.y);
			#else
				return((_ProjectionParams.z - _ProjectionParams.y) * (rawDepth) + _ProjectionParams.y);
			#endif
		#else
			//_ZBufferParams.z = 1.0/far    _ZBufferParams.w = 1.0/near
			return LinearEyeDepth(rawDepth, _ZBufferParams);
		#endif
	}
	
	float SampleAndGetLinearDepth(float2 uv)
	{
		//采样深度
		//非线性
		float rawDepth = SampleSceneDepth(uv.xy).r;
		//转换到线性
		return RawToLinearDepth(rawDepth);
	}
	
	float3 ReconstructViewPos(float2 uv, float depth, float2 p11_22, float2 p13_31)
	{
		//p13_31 多半是00
		#if defined(_ORTHOGRAPHIC)
			//Result[0][0] = static_cast<T>(2) / (right - left);
			//Result[1][1] = static_cast<T>(2) / (top - bottom);
			float3 viewPos = float3(((uv.xy * 2.0 - 1.0 - p13_31) * p11_22), depth);
		#else
			//Result[0][0] = static_cast<T>(1) / (aspect * tanHalfFovy);
			//Result[1][1] = static_cast<T>(1) / (tanHalfFovy);
			//depth是z * tan  得到屏幕屏幕宽高  * uv   得出最后位置
			float3 viewPos = float3(depth * ((uv.xy * 2.0 - 1.0 - p13_31) * p11_22), depth);
		#endif
		return viewpos;
	}
	
	
	// Try reconstructing normal accurately from depth buffer.
	// Low:    DDX/DDY on the current pixel
	// Medium: 3 taps on each direction | x | * | y |
	// High:   5 taps on each direction: | z | x | * | y | w |
	// https://atyuwen.github.io/posts/normal-reconstruction/
	// https://wickedengine.net/2019/09/22/improved-normal-reconstruction-from-depth/
	float3 ReconstructNormal(float2 uv, float depth, float3 vpos, float2 p11_22, float2 p13_31)
	{
		#if defined(_RECONSTRUCT_NORMAL_LOW)
			return normalize(cross(ddy(vpos), ddx(vpos)));
		#else
			float2 delta = _CameraDepthTexture_TexelSize.xy * 2.0;
			
			// Sample the neighbour fragments
			float2 lUV = float2(-delta.x, 0.0);
			float2 rUV = float2(delta.x, 0.0);
			float2 uUV = float2(0.0, delta.y);
			float2 dUV = float2(0.0, -delta.y);
			
			float3 l1 = float3(uv + lUV, 0.0); 
			l1.z = SampleAndGetLinearDepth(l1.xy); // Left1
			float3 r1 = float3(uv + rUV, 0.0); 
			r1.z = SampleAndGetLinearDepth(r1.xy); // Right1
			float3 u1 = float3(uv + uUV, 0.0); 
			u1.z = SampleAndGetLinearDepth(u1.xy); // Up1
			float3 d1 = float3(uv + dUV, 0.0); 
			d1.z = SampleAndGetLinearDepth(d1.xy); // Down1
			
			//TODO:hcs

			// Determine the closest horizontal and vertical pixels...
			// horizontal: left = 0.0 right = 1.0
			// vertical  : down = 0.0    up = 1.0
			#if defined(_RECONSTRUCT_NORMAL_MEDIUM)
				uint closest_horizontal = l1.z > r1.z ? 0: 1;
				uint closest_vertical = d1.z > u1.z ? 0: 1;
			#else
				float3 l2 = float3(uv + lUV * 2.0, 0.0); 
				l2.z = SampleAndGetLinearDepth(l2.xy); // Left2
				float3 r2 = float3(uv + rUV * 2.0, 0.0); 
				r2.z = SampleAndGetLinearDepth(r2.xy); // Right2
				float3 u2 = float3(uv + uUV * 2.0, 0.0); 
				u2.z = SampleAndGetLinearDepth(u2.xy); // Up2
				float3 d2 = float3(uv + dUV * 2.0, 0.0); 
				d2.z = SampleAndGetLinearDepth(d2.xy); // Down2
				
				const uint closest_horizontal = abs((2.0 * l1.z - l2.z) - depth) < abs((2.0 * r1.z - r2.z) - depth) ? 0: 1;
				const uint closest_vertical = abs((2.0 * d1.z - d2.z) - depth) < abs((2.0 * u1.z - u2.z) - depth) ? 0: 1;
			#endif
			
			
			// Calculate the triangle, in a counter-clockwize order, to
			// use based on the closest horizontal and vertical depths.
			// h == 0.0 && v == 0.0: p1 = left,  p2 = down
			// h == 1.0 && v == 0.0: p1 = down,  p2 = right
			// h == 1.0 && v == 1.0: p1 = right, p2 = up
			// h == 0.0 && v == 1.0: p1 = up,    p2 = left
			// Calculate the view space positions for the three points...
			float3 P1;
			float3 P2;
			if (closest_vertical == 0)
			{
				P1 = closest_horizontal == 0 ? l1: d1;
				P2 = closest_horizontal == 0 ? d1: r1;
			}
			else
			{
				P1 = closest_horizontal == 0 ? u1: r1;
				P2 = closest_horizontal == 0 ? l1: u1;
			}
			
			P1 = ReconstructViewPos(P1.xy, P1.z, p11_22, p13_31);
			P2 = ReconstructViewPos(P2.xy, P2.z, p11_22, p13_31);
			
			// Use the cross product to calculate the normal...
			return normalize(cross(P2 - vpos, P1 - vpos));
		#endif
	}
	
	void SampleDepthNormalView(float2 uv, float2 p11_22, float2 p13_31, out float depth, out float3 normal, out float3 vpos)
	{
		depth = SampleAndGetLinearDepth(uv);
		vpos = ReconstructViewPos(uv, depth, p11_22, p13_31);
		
		#if defined(_SOURCE_DEPTH_NORMALS)
			//如果有屏幕深度法线 则直接采样
			normal = SampleSceneNormals(uv);
		#else
			normal = ReconstructNormal(uv, depth, vpos, p11_22, p13_31);
		#endif
	}
	
	float3x3 GetCoordinateConversionParameters(out float2 p11_22, out float p13_31)
	{
		float3x3 camProj = (float3x3)unity_CameraProjection;
		
		//11 = 0行0列    13 = 0行2列
		p11_22 = rcp(float2(camProj._11, camProj._22));
		// _13  _23 默认都是 0
		p13_31 = float2(camProj._13, camProj._23);
		
		return camProj;
	}
	
	float4 SSAO(v2f input): SV_TARGET
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
		float2 uv = input.uv;
		
		//坐标转换使用参数
		float2 p11_22, p13_31;
		float3x3 camProj = GetCoordinateConversionParameters(p11_22, p13_31);
		
		//获取深度的 法线 和 视图位置
		float depth_o;
		float3 norm_o;
		float3 vpos_o;
		SampleDepthNormalView(uv, p11_22, p13_31, depth_o, norm_o, vpos_o);
	}
	
#endif