Shader "MyRP/LitSamples/01_UnlitTexture"
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
			
			struct a2v
			{
				float4 positionOS: POSITION;
				float2 uv: TEXCOORD0;
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float2 uv: TEXCOORD0;
			};
			
			//texture 可以不在 cbuffer里面  因为在Properties定义里是算 UnityPerMaterial
			//但是XX_ST需要在里面
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			v2f vert(a2v v)
			{
				v2f o;
				o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				return o;
			}
			
			half4 frag(v2f i): SV_Target
			{
				return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
			}
			
			ENDHLSL
			
		}
		
	}
}
