Shader "MyRP/LitSamples/03_UnlitTextureMatcap"
{
	Properties
	{
		[MainColor] _BaseColor ("BaseColor", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("BaseMap", 2D) = "white" { }
		[Normal][NoScaleOffset] _NormalMap ("NormalMap", 2D) = "bump" { }
		[NoScaleOffset]_MatCap ("MatCap", 2D) = "black" { }
		_MatCapBlend ("MapCap Blend", Range(0, 1)) = 0.25
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
		half _MatCapBlend;
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
				float3 normalOS: NORMAL;
				float4 tangentOS: TANGENT;
			};
			
			struct v2f
			{
				float4 positionHCS: SV_POSITION;
				float2 uv: TEXCOORD0;
				float3 positionWS: TEXCOORD1;
				float3 normalVS: TEXCOORD2;
				float4 tangentVS: TEXCOORD3;//xyz:tangentVS , w:sign to compute binormal
			};
			
			//texture 可以不在 cbuffer里面  因为在Properties定义里是算 UnityPerMaterial
			//但是XX_ST需要在里面
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			
			TEXTURE2D(_MatCap);
			SAMPLER(sampler_MatCap);
			
			v2f vert(a2v v)
			{
				v2f o;
				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
				
				o.positionHCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;
				o.normalVS = TransformWorldToViewDir(normalInputs.normalWS);
				o.tangentVS = half4(TransformWorldToViewDir(normalInputs.tangentWS), v.tangentOS.w * GetOddNegativeScale());
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				
				return o;
			}
			
			
			half4 frag(v2f i): SV_Target
			{
				float4 shadowsCoord = TransformWorldToShadowCoord(i.positionWS);
				Light mainLight = GetMainLight(shadowsCoord);
				
				float3 binormalVS = cross(i.normalVS, i.tangentVS.xyz) * i.tangentVS.w;
				float3 perturbedNormalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv));
				float3 perturbedNormalVS = normalize(mul(perturbedNormalTS, float3x3(i.tangentVS.xyz, binormalVS.xyz, i.normalVS.xyz)));
				//normal 转换成UV
				float2 uvMatCap = perturbedNormalVS.xy * 0.5 + 0.5;
				
				half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb * _BaseColor.rgb;
				half3 matCapColor = SAMPLE_TEXTURE2D(_MatCap, sampler_MatCap, uvMatCap).rgb;
				half3 finalColor = lerp(baseColor, matCapColor, _MatCapBlend);
				
				finalColor *= mainLight.shadowAttenuation;
				return half4(finalColor, 1.0);
			}
			
			ENDHLSL
			
		}
		
		UsePass "MyRP/LitSamples/02_UnlitTextureShadows/ShadowCaster"
	}
}
