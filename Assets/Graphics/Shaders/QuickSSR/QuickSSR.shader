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

				float2 noise = (SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, (IN.uv * 5) + _Time.x).xy * 2.0 - 1.0) * 0.1;
				//其实这里需要屏幕空间Normal  但是偷懒了
				float3 wsNormal = normalize(float3(noise.x, 1, noise.y));
				float3 vsNormal = TransformWorldToViewDir(wsNormal);
				
				float3 vsRayOrigin = IN.vsRay * depth;
				float3 reflectionDir = normalize(reflect(vsRayOrigin, vsNormal));
				
				float2 hitUV = 0;
				half3 col = SampleSceneColor(screenPos.xy);
				
				if(false)
				{
					
				}
				else
				{
					float3 viewDir = -GetWorldSpaceViewDir(IN.positionWS);
					float3 reflDir = reflect(viewDir,wsNormal);
					float4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflDir, 0);
					half3 envMap = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);
					col = envMap;
				}
				
				return half4(col, 1);
			}
			ENDHLSL
		}
	}
}