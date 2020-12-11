Shader "MyRP/HDR/CustomStandard"
{
	Properties
	{
		[NoScaleOffset] _MainTex ("Albedo", 2D) = "white" { }
		[NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" { }
		[NoScaleOffset] _RoughnessMap ("Roughness", 2D) = "white" { }
		[NoScaleOffset] _BumpMap ("Normal", 2D) = "bump" { }
		[NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" { }
		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" { }
		_SpecularLevel ("Specular", Range(0.0, 1.0)) = 0.5
		_BumpScale ("Bump Scale", Float) = 1.0
	}
	
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "Geometry" /*"RenderPipeline"="UniversalPipeline"*/ }
		
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite On
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			CBUFFER_START(UnityPerMaterial)
			
			TEXTURE2D_X(_MainTex);
			SAMPLER(sampler_MainTex);
			TEXTURE2D_X(_MetallicMap);
			SAMPLER(sampler_MetallicMap);
			TEXTURE2D_X(_RoughnessMap);
			SAMPLER(sampler_RoughnessMap);
			TEXTURE2D_X(_BumpMap);
			SAMPLER(sampler_BumpMap);
			TEXTURE2D_X(_OcclusionMap);
			SAMPLER(sampler_OcclusionMap);
			TEXTURE2D_X(_EmissionMap);
			SAMPLER(sampler_EmissionMap);
			half _SpecularLevel;
			half _BumpScale;
			
			CBUFFER_END
			
			struct a2v
			{
				float4 vertex: POSITION;
				float2 texcoord: TEXCOORD0;
				float3 normal: NORMAL;
				float4 tangent: TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 pos: SV_POSITION;
				float2 uv: TEXCOORD0;
				float4 TtoW0: TEXCOORD1;
				float4 TtoW1: TEXCOORD2;
				float4 TtoW2: TEXCOORD3;
				float4 shadowCoord: TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			v2f vert(a2v v)
			{
				v2f o = (v2f)0;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.uv = v.texcoord;
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal);
				half3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				half3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w * unity_WorldTransformParams.w;
				
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				
				o.shadowCoord = TransformWorldToShadowCoord(worldPos);
				
				o.pos = TransformWorldToHClip(worldPos);
				
				return o;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				float2 uv = i.uv;
				
				half4 albedo = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv);
				half specular = _SpecularLevel;
				half metallic = SAMPLE_TEXTURE2D_X(_MetallicMap, sampler_MetallicMap, uv);
				half roughness = SAMPLE_TEXTURE2D_X(_RoughnessMap, sampler_RoughnessMap, uv);
				half albedo = SAMPLE_TEXTURE2D_X(_OcclusionMap, sampler_OcclusionMap, uv);
				half emission = SAMPLE_TEXTURE2D_X(_EmissionMap, sampler_EmissionMap, uv);
				
				half3 diffColor = lerp(albedo, 0.0, metallic);
				half3 specColor = ComputeF0(specular, albedo, metallic);
			}
			
			ENDHLSL
			
		}
	}
}
