Shader "MyRP/LitSamples/02_UnlitTextureShadows"
{
	Properties
	{
		[MainColor] _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("BaseMap", 2D) = "white" { }
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" /*"RenderPipeline" = "UniversalRenderPipeline"*/ }
		
		//让全部的pass都用一样的cbuffer
		//只有相同的cbuffer才能启用SRP batcher
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		CBUFFER_START(UnityPerMaterial)
		float4 _BaseMap_ST;
		half4 _BaseColor;
		CBUFFER_END
		
		ENDHLSL
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float2 uv: TEXCOORD0;
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float2 uv: TEXCOORD0;
				float3 positionWS: TEXCOORD1;
			};
			
			//texture 可以不在 cbuffer里面  因为在Properties定义里是算 UnityPerMaterial
			//但是XX_ST需要在里面
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			v2f vert(a2v v)
			{
				v2f o;
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				o.positionHCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				return o;
			}
			
			half4 frag(v2f i): SV_Target
			{
				float4 shadowsCoord = TransformWorldToShadowCoord(i.positionWS);
				Light mainLight = GetMainLight(shadowsCoord);
				half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
				color *= mainLight.shadowAttenuation;
				return color;
			}
			
			ENDHLSL
			
		}
		
		//可以直接使用Lit的ShadowCaster
		//但是存在问题就是 ShadowCaster 的 UnityPerMaterial CBUFFER 不一致 不能 进行SRP Batcher
		//要么就是 重写我们的UnityPerMaterial   要么就是自己写个ShadowCaster
		//UsePass "Universal Render Pipeline/Lit/ShadowCaster"
		Pass
		{
			
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			
			ColorMask 0
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float3 normalOS: NORMAL;
				float2 texcoord: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
			};
			
			float3 _LightDirection;
			
			
			float4 GetShadowPositionHClip(a2v input)
			{
				float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
				float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
				
				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
				
				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				
				return positionCS;
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				o.positionHCS = GetShadowPositionHClip(v);
				return o;
			}
			
			
			half4 frag(v2f v): SV_Target
			{
				return 0;
			}
			
			ENDHLSL
			
		}
	}
}
