//https://zhuanlan.zhihu.com/p/355949234
//https://zhuanlan.zhihu.com/p/137089688
Shader "MyRP/QuickSSR/QuickSSR"
{
	Properties
	{
		_NoiseTex("NoiseTex",2D) = "grey"{}
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Transparent" "Queue"="Transparent"
		}
		ZWrite Off
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


			#define MAX_TRACE_DIS 500
			#define MAX_IT_COUNT 200
			#define EPSION 0.1

			struct a2v
			{
				float4 vertex :POSITION;
				float2 uv :TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float4 positionOS : TEXCOORD2;
				float2 positionCS : TEXCOORD3;
				float3 vsRay : TEXCOORD4;
			};

			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);

			float2 ViewPosToCS(float3 vpos)
			{
				float4 proj_pos = mul(unity_CameraProjection, float4(vpos, 1));
				float2 screenPos = proj_pos.xy / proj_pos.w;
				return screenPos * 0.5 + 0.5;
			}

			float CompareWithDepth(float3 vpos)
			{
				float2 uv = ViewPosToCS(vpos);
				float depth = SampleSceneDepth(uv);
				depth = LinearEyeDepth(depth, _ZBufferParams);
				int isInside = uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
				return lerp(0, vpos.z + depth, isInside);
			}

			bool RayMarching(float3 o, float3 r, out float2 hitUV)
			{
				const int max_marching = 256;
				const float max_distance = 500;
				
				float3 end = o;
				float stepSize = 0.5;
				float thinkness = 0.1;
				float triveled = 0;


				UNITY_LOOP
				for (int i = 1; i <= max_marching; ++i)
				{
					end += r * stepSize;
					triveled += stepSize;

					if (triveled > max_distance)
					{
						return false;
					}

					float collied = CompareWithDepth(end);
					if (collied < 0)
					{
						if (abs(collied) < thinkness)
						{
							hitUV = ViewPosToCS(end);
							return true;
						}

						//回到当前的起点
						end -= r * stepSize;
						triveled -= stepSize;
						//步进减半
						stepSize *= 0.5;
					}
				}
				return false;
			}

			v2f vert(a2v IN)
			{
				v2f o;
				o.uv = IN.uv;
				VertexPositionInputs positions = GetVertexPositionInputs(IN.vertex.xyz);
				o.vertex = positions.positionCS;
				o.positionOS = IN.vertex;
				o.positionWS = positions.positionWS;

				float2 divPos = positions.positionCS.xy / positions.positionCS.w;
				#if UNITY_UV_STARTS_AT_TOP
				divPos.y = -divPos.y;
				#endif
				o.positionCS = divPos * 0.5 + 0.5;


				float zFar = _ProjectionParams.z;
				float4 vsRay = float4(divPos * zFar, zFar, zFar);
				vsRay = mul(unity_CameraInvProjection, vsRay);

				o.vsRay = vsRay.xyz;

				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				/*
				float4 screenPos = TransformObjectToHClip(i.positionOS);
				screenPos.xyz /= screenPos.w;
				screenPos.xy = screenPos.xy * 0.5 + 0.5;
				screenPos.y = 1 - screenPos.y;
				
				float4 cameraRay = float4(screenPos.xy * 2.0 - 1.0, 1, 1.0);
				cameraRay = mul(unity_CameraInvProjection, cameraRay);
				i.vsRay = cameraRay / cameraRay.w;*/

				//世界空间射线
				/*float3 normalWS = TransformObjectToWorldDir(float3(0, 1, 0));
				

				float3 viewDir = normalize(i.positionWS - _WorldSpaceCameraPos);
				float3 reflectDir = reflect(viewDir, normalWS);
				float3 reflectPos = i.positionWS;

				float3 col = RayTracePixel(reflectPos, reflectDir);
				*/
				float2 screenPos = IN.positionCS;

				float depth = SampleSceneDepth(screenPos);
				depth = Linear01Depth(depth, _ZBufferParams);

				float2 noise = 0.1 * (SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, (IN.uv * 5) + _Time.x).xy * 2.0 - 1.0);
				
				//其实这里需要屏幕空间Normal  但是偷懒了
				float3 wsNormal = normalize(float3(noise.x, 1, noise.y));
				float3 vsNormal = TransformWorldToViewDir(wsNormal);

				float3 vsRayOrigin = IN.vsRay * depth;
				float3 reflectionDir = normalize(reflect(vsRayOrigin, vsNormal));

				float2 hitUV = 0;
				half3 col = SampleSceneColor(screenPos.xy);
				
				if (RayMarching(vsRayOrigin, reflectionDir, hitUV))
				{
					col = SampleSceneColor(hitUV);
				}
				else
				{
					float3 viewDir = -GetWorldSpaceViewDir(IN.positionWS);
					float3 reflDir = reflect(viewDir, wsNormal);
					float4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflDir, 0);
					col = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);
				}

				return half4(col, 1);
			}
			ENDHLSL
		}
	}
}