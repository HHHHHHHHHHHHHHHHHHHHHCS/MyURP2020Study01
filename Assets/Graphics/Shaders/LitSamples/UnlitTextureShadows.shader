Shader "LitSamples/01/UnlitTextureShadows"
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
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			v2f vert(a2v i)
			{
				v2f o;
				VertexPositionInputs positionInputs = GetVertexPositionInputs(i.positionOS.xyz);
				o.positionHCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;
				o.uv = TRANSFORM_TEX(i.uv, _BaseMap);
				return o;
			}
			
			half4 frag(v2f v): SV_Target
			{
				float4 shadowsCoord = TransformWorldToShadowCoord(v.positionWS);
				Light mainLight = GetMainLight(shadowsCoord);
				half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, v.uv) * _BaseColor;
				color *= mainLight.shadowAttenuation;
				return color;
			}
			
			ENDHLSL
			
		}
		
		//可以直接使用Lit的ShadowCaster
		//但是存在问题就是 ShadowCaster 的 UnityPerMaterial CBUFFER 不一致 不能 进行SRP Batcher
		//要么就是 重写我们的UnityPerMaterial   要么就是自己写个ShadowCaster
		//UsePass "Universal Render Pipeline/Lit/ShadowCaster"
		//TODO:抽出来自己写
		Pass
		{
			
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			
			ColorMask 0
			
			HLSLPROGRAM
			
			//ShadowPassVertex->是ShadowCasterPass.hlsl里面的
			#pragma vertex ShadowPassVertex
			#pragma fragment frag
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
			
			
			half4 frag(v2f v): SV_Target
			{
				return 0;
			}
			
			ENDHLSL
			
		}
	}
}
