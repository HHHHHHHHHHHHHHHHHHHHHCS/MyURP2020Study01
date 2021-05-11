Shader "MyRP/AtmosphericScattering//LightShaft"
{
	Properties
	{
		//_DitheringTex("Texture",2D) = "white"{}
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			HLSLPROGRAM
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			TEXTURE2D(_DitheringTex);
			SAMPLER(sampler_Point_Repeat);
			float3 _FrustumCorners[4];
			float _DistanceScale;

			struct a2v
			{
				float3 vertex : POSITION;
				float2 uv : TEXCOORD0;
				uint vertexID : SV_VertexID;
			};

			struct v2f
			{
				float4 positionCS:SV_POSITION;
				float2 uv:TEXCOORD0;
				float3 frustumCornerDirWS:TEXCOORD1;
			};

			v2f vert(a2v IN)
			{
				v2f o;
				o.positionCS = TransformObjectToHClip(IN.vertex);
				o.frustumCornerDirWS = _FrustumCorners[IN.vertexID];
				o.uv = IN.uv;
				return o;
			}

			real SampleShadowMap(float3 positionWS)
			{
				float4 shadowCoords = TransformWorldToShadowCoord(positionWS);
				return MainLightRealtimeShadow(shadowCoords);
			}

			half4 frag(v2f IN):SV_Target
			{
				#if !defined(_MAIN_LIGHT_SHADOWS)
				return half4(1, 1, 1, 1);
				#endif

				float depth = SampleSceneDepth(IN.uv);
				//_ZBufferParams.z = 1.0/far    _ZBufferParams.w = 1.0/near
				depth = Linear01Depth(depth, _ZBufferParams);

				half dither = SAMPLE_TEXTURE2D(_DitheringTex, sampler_Point_Repeat, IN.uv.xy*_ScreenParams.xy / 8).r;

				float3 positionWS = _WorldSpaceCameraPos + IN.frustumCornerDirWS * depth;
				float3 rayStart = _WorldSpaceCameraPos;
				float3 rayDir = positionWS - rayStart;
				float rayLength = length(rayDir);
				rayDir /= rayLength;

				//ray是否可以从 rayStart + 0.5*step 开始
				const int sampleCount = 16;
				float step = rayLength / sampleCount;
				float totalAtten = 0;
				float3 p = rayStart + rayDir * step * dither;

				for (int i = 0; i < sampleCount; i++)
				{
					real atten = SampleShadowMap(p);
					totalAtten += atten;
					p += rayDir * step;
				}

				totalAtten /= sampleCount;
				return half4(totalAtten.xxx, 1);
			}
			ENDHLSL
		}

	}
}