Shader "MyRP/HairShadow/HairShadow"
{
	Properties
	{
		[MainTexture]_BaseMap ("Base Map", 2D) = "white" { }
		_BaseColor ("Base Color", Color) = (0, 0.66, 0.73, 1)

		[Header(Shading)]
		_BrightColor ("BrightColor", Color) = (1, 1, 1, 1)
		[HDR]_MiddleColor ("MiddleColor", Color) = (0.8, 0.1, 0.1, 1)
		_DarkColor ("DarkColor", Color) = (0.5, 0.5, 0.5, 1)
		_CelShadeMidPoint ("CelShadeMidPoint", Range(0, 1)) = 0.5
		_CelShadeSmoothness ("CelShadeSmoothness", Range(0, 1)) = 0.1
		[Toggle(_IsFace)] _IsFace ("IsFace", Float) = 0.0
		_HairShadowDistace ("_HairShadowDistance", Float) = 1

		[Header(Rim)]
		_RimColor ("RimColor", Color) = (1, 1, 1, 1)
		_RimSmoothness ("RimSmoothness", Range(0, 10)) = 10
		_RimStrength ("RimStrength", Range(0, 1)) = 0.1

		[Header(OutLine)]
		_OutLineColor ("OutLineColor", Color) = (0, 0, 0, 1)
		_OutLineThickness ("OutLineThickness", float) = 0.5
		[Toggle(_UseColor)] _UseColor ("UseVertexColor", Float) = 0.0

		[Header(heightCorrectMask)]
		_HeightCorrectMax ("HeightCorrectMax", float) = 1.6
		_HeightCorrectMin ("HeightCorrectMin", float) = 1.51
	}
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

	#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
	#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
	#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
	#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
	#pragma multi_compile _ _SHADOWS_SOFT

	CBUFFER_START(UnityPerMaterial)
	float4 _BaseMap_ST;
	float4 _BaseColor, _BrightColor, _DarkColor, _OutLineColor, _MiddleColor, _RimColor;
	float _CelShadeMidPoint, _CelShadeSmoothness, _OutLineThickness;
	float _RimSmoothness, _RimStrength, _HairShadowDistace, _HeightCorrectMax, _HeightCorrectMin;


	CBUFFER_END
	ENDHLSL
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline"
		}

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _IsFace

			struct a2v
			{
				float4 positionOS : POSITION;
				float4 normal : NORMAL;
				float3 color : COLOR;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 normal : TEXCOORD2;
				float3 color : TEXCOORD3;
				#if _IsFace
				float4 positionSS : TEXCOORD4;
				float posNDCw : TEXCOORD5;
				float4 positionOS : TEXCOORD6;
				#endif
			};

			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(_HairSolidColor);
			SAMPLER(sampler_HairSolidColor);

			v2f vert(a2v v)
			{
				v2f o;

				VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
				o.positionCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;

				#if _IsFace
				o.posNDCw = positionInputs.positionWS.w;
				o.positionSS = ComputeScreenPos(positionInputs.positionCS);
				o.positionOS = v.positionOS;
				#endif

				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

				VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(v.normal.xyz);
				o.normal = vertexNormalInput.normalWS;

				o.color = v.color;
				return o;
			}

			half4 frag(v2f i):SV_Target
			{
				half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
				float3 normal = normalize(i.normal);

				//get light and receive shadow
				Light mainLight;
				#if _MAIN_LIGHT_SHADOWS
					float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS.xyz);
					Light light = GetMainLight(shadowCoord);
				#else
				mainLight = GetMainLight();
				#endif
				real shadow = mainLight.shadowAttenuation * mainLight.distanceAttenuation;

				//basic cel shading
				float CelShadeMidPoint = _CelShadeMidPoint;
				float halfLambert = dot(normal, mainLight.direction) * 0.5 + 0.5;
				half ramp = smoothstep(0, CelShadeMidPoint,
				                       pow(saturate(halfLambert - CelShadeMidPoint), _CelShadeSmoothness));
			}
			ENDHLSL
		}

		Pass
		{
			Name "ShadowCaster"
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			ZWrite On
			ZTest LEqual
			Cull Back

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature _ALPHATEST_ON

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
			ENDHLSL
		}
	}
}