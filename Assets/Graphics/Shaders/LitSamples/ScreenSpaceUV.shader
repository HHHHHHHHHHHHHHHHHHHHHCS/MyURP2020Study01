Shader "MyRP/LitSamples/04_ScreenSpaceUV"
{
	Properties
	{
		[MainColor] _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("BaseMap", 2D) = "white" { }
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" /*"RenderPipeline" = "UniversalRenderPipeline"*/ }
		
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
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float3 positionWS: TEXCOORD0;
			};
			
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			v2f vert(a2v v)
			{
				v2f o;
				
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				
				o.positionHCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;
				return o;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
				
				Light mainLight = GetMainLight(shadowCoord);
				
				//这里positionHCS->SV_Target已经成为像素位置了  所以写法很平常的ComputeScreenPos不一样
				float2 uv = (i.positionHCS.xy / _ScreenParams.xy) * _BaseMap_ST.xy + _BaseMap_ST.zw;
				half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb * _BaseColor.rgb;
				half3 finalColor = baseColor * mainLight.shadowAttenuation;
				return half4(finalColor, 1.0);
			}
			
			ENDHLSL
			
		}
		
		UsePass "MyRP/LitSamples/02_UnlitTextureShadows/ShadowCaster"
	}
}
