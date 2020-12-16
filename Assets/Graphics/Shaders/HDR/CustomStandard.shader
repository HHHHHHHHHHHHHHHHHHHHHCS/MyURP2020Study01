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
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			#include "CustomStandardBRDF.hlsl"
			
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
				half3 worldNormal = TransformObjectToWorldNormal(v.normal);
				half3 worldTangent = TransformObjectToWorldDir(v.tangent.xyz);
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
				
				half3 albedo = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv).rgb;
				half specular = _SpecularLevel;
				half metallic = SAMPLE_TEXTURE2D_X(_MetallicMap, sampler_MetallicMap, uv).r;
				half roughness = SAMPLE_TEXTURE2D_X(_RoughnessMap, sampler_RoughnessMap, uv).r;
				half occlusion = SAMPLE_TEXTURE2D_X(_OcclusionMap, sampler_OcclusionMap, uv).r;
				half3 emission = SAMPLE_TEXTURE2D_X(_EmissionMap, sampler_EmissionMap, uv).rgb;
				
				half3 diffColor = lerp(albedo, 0.0, metallic);
				half3 specColor = ComputeF0(specular, albedo, metallic);
				
				half3 normalTangent = UnpackNormal(SAMPLE_TEXTURE2D_X(_BumpMap, sampler_BumpMap, i.uv));
				normalTangent.xy *= _BumpScale;
				normalTangent.z = sqrt(1.0 - saturate(dot(normalTangent.xy, normalTangent.xy)));
				half3 normalWorld = normalize(half3(dot(i.TtoW0.xyz, normalTangent), dot(i.TtoW1.xyz, normalTangent), dot(i.TtoW2.xyz, normalTangent)));
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				
				half3 viewDir = normalize(GetWorldSpaceViewDir(worldPos));
				half3 reflDir = reflect(-viewDir, normalWorld);
				Light mainLight = GetMainLight(i.shadowCoord);
				
				//计算直接光=直接光照颜色
				//------------------------------
				half3 lightColor = mainLight.color;
				half3 lightDir = normalize(mainLight.direction);
				half3 halfDir = normalize(lightDir + viewDir);
				half nv = saturate(dot(normalWorld, viewDir));
				half nl = saturate(dot(normalWorld, lightDir));
				half nh = saturate(dot(normalWorld, halfDir));
				half lv = saturate(dot(lightDir, viewDir));
				half lh = saturate(dot(lightDir, halfDir));
				
				//diffuse term
				half3 diffuseTerm = DisneyDiffuseTerm(nv, nl, lh, roughness, diffColor);
				
				//specular term
				half V = SmithJointGGXVisibilityTerm(nl, nv, roughness);
				half D = GGXTerm(nh, roughness * roughness);
				half3 F = FresnelTerm(specColor, lh);
				half3 specularTerm = F * V * D;
				
				half3 directLighting = PI * (diffuseTerm + specularTerm) * lightColor * nl * mainLight.distanceAttenuation;
				
				//计算间接光=漫反射+镜面反射=球谐+反射球
				//----------------------
				half3 indirectDiffuse = max(0.0, SampleSH(normalWorld)) * diffColor * occlusion;
				
				half specOcclusion = GetSpecularOcclusion(metallic, roughness, occlusion);
				half envMip = ComputeEnvMipmapFromRoughness(roughness);
				float4 rgbm = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflDir, envMip);
				half3 envMap = DecodeHDR(rgbm, unity_SpecCube0_HDR);
				half3 indirectSpecular = envMap * specOcclusion * EnvBRDF(specColor, roughness, nv);
				
				half3 indirectLighting = indirectDiffuse + indirectSpecular;
				
				//最后
				//-------------------------
				half3 col = emission + directLighting + indirectLighting;
				return half4(col, 1);
			}
			
			ENDHLSL
			
		}
	}
}
