Shader "MyRP/CartoonWater/GradientSkybox"
{
	Properties
	{
		_Tiling ("Tiling", Vector) = (5, 5, 0, 0)
		_Density ("Density", Range(0, 1)) = 0.25
		_Size ("Size", Range(0.1, 1)) = 0.5
		_Thickness ("Thickness", Range(0.025, 0.25)) = 0.1
		_StarColor ("Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Tags { /*"RenderPipeline" = "UniversalPipeline"*/ "RenderType" = "Background" "Queue" = "Background" "PreviewType" = "Skybox" "PreviewType" = "Skybox" }
		Cull Off
		ZWrite Off
		
		Pass
		{
			// Skybox
			Name "Skybox"
			// Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			//#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			// Keywords
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma shader_feature _ _SAMPLE_GI
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 positionWS: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct MyGradient
			{
				int type;
				int colorsLength;
				int alphasLength;
				float4 colors[8];
				float2 alphas[8];
			};
			
			CBUFFER_START(UnityPerMaterial)
			float2 _Tiling;
			float _Density;
			float _Size;
			float _Thickness;
			float4 _StarColor;
			CBUFFER_END
			
			inline float RandomRange(float2 seed, float minVal, float maxVal)
			{
				float rd = frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
				return lerp(minVal, maxVal, rd);
			}
			
			inline float Ellipse(float2 uv, float width, float height)
			{
				float d = length((uv * 2 - 1) / float2(width, height));
				return saturate((1 - d) / fwidth(d));
			}
			
			inline float Remap(float input, float2 inMinMax, float2 outMinMax)
			{
				return outMinMax.x + (input - inMinMax.x) * (outMinMax.y - outMinMax.x) / (inMinMax.y - inMinMax.x);
			}
			
			MyGradient NewMyGradient(int type, int colorsLength, int alphasLength,
			float4 colors0, float4 colors1, float4 colors2, float4 colors3, float4 colors4, float4 colors5, float4 colors6, float4 colors7,
			float2 alphas0, float2 alphas1, float2 alphas2, float2 alphas3, float2 alphas4, float2 alphas5, float2 alphas6, float2 alphas7)
			{
				MyGradient output = {
					type, colorsLength, alphasLength,
					{
						colors0, colors1, colors2, colors3, colors4, colors5, colors6, colors7
					},
					{
						alphas0, alphas1, alphas2, alphas3, alphas4, alphas5, alphas6, alphas7
					}
				};
				return output;
			}
			
			inline float4 SampleGradient(MyGradient gradient, float val)
			{
				float3 color = gradient.colors[0].rgb;
				[unroll]
				for (int c = 1; c < 8; c ++)
				{
					float colorPos = saturate((val - gradient.colors[c - 1].w) / (gradient.colors[c].w - gradient.colors[c - 1].w)) * step(c, gradient.colorsLength - 1);
					color = lerp(color, gradient.colors[c].rgb, lerp(colorPos, step(0.01, colorPos), gradient.type));
				}
				#ifndef UNITY_COLORSPACE_GAMMA
					color = SRGBToLinear(color);
				#endif
				
				float alpha = gradient.alphas[0].x;
				[unroll]
				for (int a = 1; a < 8; a ++)
				{
					float alphaPos = saturate((val - gradient.alphas[a - 1].y) / (gradient.alphas[a].y - gradient.alphas[a - 1].y)) * step(a, gradient.alphasLength - 1);
					alpha = lerp(alpha, gradient.alphas[a].x, lerp(alphaPos, step(0.01, alphaPos), gradient.type));
				}
				
				return float4(color, alpha);
			}
			
			//球转换成UV
			float2 SphericalUV(float3 worldPosition)
			{
				float3 dir = normalize(worldPosition);
				float2 uv;
				uv.x = atan2(dir.x, dir.z) / TWO_PI;
				uv.y = asin(dir.y) / HALF_PI;
				return uv;
			}
			
			float RandomByTileUV(float2 uv)
			{
				uv = uv * _Tiling;
				float2 fracUV = frac(uv);
				float2 floorUV = floor(uv);
				float size = RandomRange(floorUV * float2(314, 314), 0.1, 0.75);
				float ret = Ellipse(fracUV, size, size);
				ret *= step(1 - _Density, RandomRange(floorUV, 0, 1));
				return ret;
			}
			
			float4 SkyColor(float3 wPos, float val)
			{
				float remapVal = Remap(normalize(wPos).g, float2(-1, 1), float2(0, 1));
				MyGradient gradient = NewMyGradient(0, 3, 2, float4(1, 1, 1, 0.597055), float4(0.96, 0.75008, 0.5664, 0.6911727), float4(0.1147451, 0.7252955, 0.8196079, 0.7617609), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float2(1, 0), float2(1, 1), float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0));
				
				
				return(1 - val) * SampleGradient(gradient, remapVal);
			}
			
			float4 StarColor(float val)
			{
				return _StarColor * val;
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = v.vertex.xyz;
				o.positionCS = TransformObjectToHClip(v.vertex.xyz);
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				
				float2 uv = SphericalUV(i.positionWS);
				float noise = RandomByTileUV(uv);
				float4 skyColor = SkyColor(i.positionWS, noise);
				float4 starColor = StarColor(noise);
				
				
				return skyColor + starColor;
			}
			
			ENDHLSL
			
		}
	}
}
