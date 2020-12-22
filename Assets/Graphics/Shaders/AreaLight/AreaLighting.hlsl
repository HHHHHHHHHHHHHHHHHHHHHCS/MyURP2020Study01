#ifndef __AREALIGHTING__INCLUDE__
	#define __AREALIGHTING__INCLUDE__
	
	#if AREA_LIGHT_ENABLE_DIFFUSE
		TEXTURE2D_X(_TransformInv_Diffuse);
		SAMPLER(sampler_TransformInv_Diffuse);
	#endif
	TEXTURE2D_X(_TransformInv_Specular);
	SAMPLER(sampler_TransformInv_Specular);
	TEXTURE2D_X(_AmpDiffAmpSpecFresnel);
	SAMPLER(sampler_AmpDiffAmpSpecFresnel);
	
	float4x4 _LightVerts;
	
	half IntegrateEdge(half3 v1, half3 v2)
	{
		half theta = acos(max(-0.9999, dot(v1, v2)));
		half theta_sintheta = theta / sin(theta);
		return theta_sintheta * (v1.x * v2.y - v1.y * v2.x);
	}
	
	half PolygonRadiance(half4x3 L)
	{
		//z<=0 则在后面 不可见
		uint config = 0;
		if (L[0].z > 0)
		{
			config += 1;
		}
		if (L[1].z > 0)
		{
			config += 2;
		}
		if (L[2].z > 0)
		{
			config += 4;
		}
		if (L[3].z > 0)
		{
			config += 8;
		}
		
		//第五个顶点用于剪切时切断一个角点的情况。
		//由于编译器错误，将L复制到包含5行的向量数组中
		//把事情搞砸了，所以我们需要用矩阵+L4顶点。
		half3 L4 = L[3];
		
		//尝试用顶点的查找数组替换它。
		//尽管这只是用一些索引代替了开关，没有分支
		//但是还是比较慢
		
		//n代表 被裁剪后 一共有几个顶点
		uint n = 0;
		switch(config)
		{
			case 0: // clip all
			{
				break;
			}
			
			case 1: // V1 clip V2 V3 V4
			{
				n = 3;
				L[1] = -L[1].z * L[0] + L[0].z * L[1];
				L[2] = -L[3].z * L[0] + L[0].z * L[3];
				break;
			}
			
			case 2: // V2 clip V1 V3 V4
			{
				n = 3;
				L[0] = -L[0].z * L[1] + L[1].z * L[0];
				L[2] = -L[2].z * L[1] + L[1].z * L[2];
				break;
			}
			
			
			case 3: // V1 V2 clip V3 V4
			{
				n = 4;
				L[2] = -L[2].z * L[1] + L[1].z * L[2];
				L[3] = -L[3].z * L[0] + L[0].z * L[3];
				break;
			}
			
			
			case 4: // V3 clip V1 V2 V4
			{
				n = 3;
				L[0] = -L[3].z * L[2] + L[2].z * L[3];
				L[1] = -L[1].z * L[2] + L[2].z * L[1];
				break;
			}
			
			
			case 5: // V1 V3 clip V2 V4: impossible
			{
				break;
			}
			
			case 6: // V2 V3 clip V1 V4
			{
				n = 4;
				L[0] = -L[0].z * L[1] + L[1].z * L[0];
				L[3] = -L[3].z * L[2] + L[2].z * L[3];
				break;
			}
			
			case 7: // V1 V2 V3 clip V4
			{
				n = 5;
				L4 = -L[3].z * L[0] + L[0].z * L[3];
				L[3] = -L[3].z * L[2] + L[2].z * L[3];
				break;
			}
			
			case 8: // V4 clip V1 V2 V3
			{
				n = 3;
				L[0] = -L[0].z * L[3] + L[3].z * L[0];
				L[1] = -L[2].z * L[3] + L[3].z * L[2];
				L[2] = L[3];
				break;
			}
			
			case 9: // V1 V4 clip V2 V3
			{
				n = 4;
				L[1] = -L[1].z * L[0] + L[0].z * L[1];
				L[2] = -L[2].z * L[3] + L[3].z * L[2];
				break;
			}
			
			
			case 10: // V2 V4 clip V1 V3: impossible
			{
				break;
			}
			
			case 11: // V1 V2 V4 clip V3
			{
				n = 5;
				L[3] = -L[2].z * L[3] + L[3].z * L[2];
				L[2] = -L[2].z * L[1] + L[1].z * L[2];
				break;
			}
			
			
			case 12: // V3 V4 clip V1 V2
			{
				n = 4;
				L[1] = -L[1].z * L[2] + L[2].z * L[1];
				L[0] = -L[0].z * L[3] + L[3].z * L[0];
				break;
			}
			
			
			case 13: // V1 V3 V4 clip V2
			{
				n = 5;
				L[3] = L[2];
				L[2] = -L[1].z * L[2] + L[2].z * L[1];
				L[1] = -L[1].z * L[0] + L[0].z * L[1];
				break;
			}
			
			
			case 14: // V2 V3 V4 clip V1
			{
				n = 5;
				L4 = -L[0].z * L[3] + L[3].z * L[0];
				L[0] = -L[0].z * L[1] + L[1].z * L[0];
				break;
			}
			
			
			case 15: // V1 V2 V3 V4
			{
				n = 4;
				break;
			}
		}
		
		if (n == 0)
		{
			return 0;
		}
		
		//normalize
		L[0] = normalize(L[0]);
		L[1] = normalize(L[1]);
		L[2] = normalize(L[2]);
		if (n == 3)
		{
			L[3] = L[0];
		}
		else
		{
			L[3] = normalize(L[3]);
			if (n == 4)
			{
				L4 = L[0];
			}
			else
			{
				L4 = normalize(L4);
			}
		}
		
		half sum = 0;
		sum += IntegrateEdge(L[0], L[1]);
		sum += IntegrateEdge(L[1], L[2]);
		sum += IntegrateEdge(L[2], L[3]);
		if (n >= 4)
		{
			sum += IntegrateEdge(L[3], L4);
		}
		if (n == 5)
		{
			sum += IntegrateEdge(L4, L[0]);
		}
		
		sum *= 0.15915;
		
		return max(0, sum);
	}
	
	half TransformedPolygonRadiance(half4x3 L, half2 uv, TEXTURE2D_X(transformInv), SAMPLER(sampler_transformInv), half amplitude)
	{
		// Get the inverse LTC matrix M
		half3x3 minv = 0;
		minv._m22 = 1;
		minv._m00_m02_m11_m20 = SAMPLE_TEXTURE2D_X(transformInv, sampler_transformInv, uv);
		
		half4x3 LTrasnformed = mul(L, minv);
		
		return PolygonRadiance(LTrasnformed) * amplitude;
	}
	
	half3 CalculateLight(half3 position, half3 diffColor, half3 specColor, half oneMinusRoughness, half3 N, half3 lightPos, half3 lightColor)
	{
		#if AREA_LIGHT_SHADOWS
			half shadow = Shadow(position);
			if (shadow == 0.0)
			{
				return 0;
			}
		#endif
		
		//太大或者太小的值会失真
		oneMinusRoughness = clamp(oneMinusRoughness, 0.01, 0.93);
		half roughness = 1 - oneMinusRoughness;
		half3 V = normalize(GetWorldSpaceViewDir(position));
		
		//形成 N,V 有关的正交基
		half3x3 basis;
		basis[0] = normalize(V - N * dot(V, N));
		basis[1] = normalize(cross(N, basis[0]));
		basis[2] = N;
		
		//把光顶点转换到对应的空间
		half4x3 L;
		L = (half4x3)_LightVerts - half4x3(position, position, position, position);
		L = mul(L, transpose(basis));
		
		//UVs for sampling the LUTs
		half theta = acos(dot(V, N));
		half2 uv = half2(roughness, theta / HALF_PI);
		
		half3 AmpDiffAmpSpecFresnel = SAMPLE_TEXTURE2D_X(_AmpDiffAmpSpecFresnel, sampler_AmpDiffAmpSpecFresnel, uv).rgb;
		
		half3 result = 0;
		#if AREA_LIGHT_ENABLE_DIFFUSE
			half diffuseTerm = TransformedPolygonRadiance(L, uv, _TransformInv_Diffuse, sampler_TransformInv_Diffuse, AmpDiffAmpSpecFresnel.x);
			result = diffuseTerm * diffColor;
		#endif
		
		half specularTerm = TransformedPolygonRadiance(L, uv, _TransformInv_Specular, sampler_TransformInv_Specular, AmpDiffAmpSpecFresnel.y);
		half fresnelFactor = max(specColor.r, max(specColor.g, specColor.b));
		half fresnelTerm = fresnelFactor + (1.0 - fresnelFactor) * AmpDiffAmpSpecFresnel.z;
		result += specularTerm * fresnelTerm * PI;
		
		#if AREA_LIGHT_SHADOWS
			result *= shadow;
		#endif
		
		return result * lightColor;
	}
	
#endif