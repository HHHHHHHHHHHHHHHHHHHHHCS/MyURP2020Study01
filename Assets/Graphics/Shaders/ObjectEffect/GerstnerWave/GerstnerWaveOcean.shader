Shader "MyRP/GerstnerWave/GerstnerWaveOcean"
{
	Properties
	{
		[Header(BaseShading)]
		_BaseMap ("Example Texture", 2D) = "white" { }
		[HDR]_BaseColor ("Base Colour", Color) = (0, 0.66, 0.73, 1)
		_WaterFogColor ("Water Fog Colour", Color) = (0, 0.66, 0.73, 1)
		_FogDensity ("Fog Density", range(0, 1)) = 0.1
		_NormalMap ("Normal Map", 2D) = "white" { }
		_NormalScale ("Normal Scale", Range(0, 1)) = 0.1
		_Shininess ("High Light Roughness", Range(0, 0.1)) = 0.01
		[Space(20)]
		[Header(Reflection)]
		_Skybox ("Skybox", Cube) = "white" { }
		[Header(Refractive)]
		_AirRefractiveIndex ("Air Refractive Index", Float) = 1.0
		_WaterRefractiveIndex ("Water Refractive Index", Float) = 1.333
		_FresnelPower ("Fresnel Power", Range(0.1, 50)) = 5
		_RefractionStrength ("Refraction Strength", Range(0, 1)) = 0.1

		[Space(20)]
		[Header(SSS)]
		_FrontSubsurfaceDistortion ("Front Subsurface Distortion", Range(0, 1)) = 0.5
		_BackSubsurfaceDistortion ("Back Subsurface Distortion", Range(0, 1)) = 0.5
		_FrontSSSIntensity ("Front SSS Intensity", float) = 0.2
		_HeightCorrection ("SSS Height Correction", float) = 6

		[Space(20)]
		[Header(Foam)]
		_FoamIntensity ("Foam Intensity", float) = 0.5
		_FoamNoiseTex ("Foam Noise", 2D) = "white" { }

		[Space(20)]
		[Header(Caustic)]
		_CausticIntensity ("Caustic Intensity", float) = 0.5
		_CausticTex ("Caustic Texture", 2D) = "white" { }
		_Caustics_Speed ("Caustics Speed,(x,y)&(z,w)", Vector) = (1, 1, -1, -1)

		[Space(20)]
		[Header(Waves)]
		_Speed ("Speed", float) = 0.2
		_Frequency ("Frequency", float) = 2
		_WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1, 0, 0.5, 10)
		_WaveB ("Wave B", Vector) = (0, 1, 0.25, 20)
		_WaveC ("Wave C", Vector) = (1, 1, 0.15, 10)
		_WaveD ("Wave D", Vector) = (0, 1, 0.25, 20)
		_WaveE ("Wave E", Vector) = (1, 1, 0.15, 10)
		_WaveF ("Wave F", Vector) = (0, 1, 0.25, 20)
		_WaveG ("Wave G", Vector) = (1, 1, 0.15, 10)
		_WaveH ("Wave H", Vector) = (0, 1, 0.25, 20)
		_WaveI ("Wave I", Vector) = (1, 1, 0.15, 10)
		_WaveJ ("Wave J", Vector) = (1, 1, 0.15, 10)
		_WaveK ("Wave K", Vector) = (1, 1, 0.15, 10)
		_WaveL ("Wave L", Vector) = (1, 1, 0.15, 10)
		[Space(20)]
		[Header(Tessellation)]
		_TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
		_TessellationEdgeLength ("Tessellation Edge Length", Range(5, 100)) = 50
		[Toggle(_TESSELLATION_EDGE)]_TESSELLATION_EDGE ("TESSELLATION EDGE", float) = 0
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "RenderQueue" = "Transparent"
		}

		Pass
		{
			Name "GerstnerWaveOcean"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			ZWrite Off

			HLSLPROGRAM
			#pragma target 4.6

			#pragma vertex tessVert
			#pragma hull tessHull
			#pragma domain tessDomain
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			#include "GerstnerWaveLib.hlsl"
			#include "GerstnerWaveTessellation.hlsl"

			#pragma shader_feature _TESSELLATION_EDGE

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT

			CBUFFER_START(UnityPerMaterial)
			float4 _BaseMap_ST, _FoamNoiseTex_ST, _CausticTex_ST;
			float4 _BaseColor, _WaterFogColor, _Caustics_Speed;
			float4 _NormalMap_ST;
			float4 _WaveA, _WaveB, _WaveC, _WaveD, _WaveE, _WaveF, _WaveG, _WaveH, _WaveI, _WaveJ, _WaveK, _WaveL;
			float _Speed, _Frequency, _NormalScale, _AirRefractiveIndex, _WaterRefractiveIndex, _FresnelPower;
			float _RefractionStrength, _FogDensity, _Shininess, _FrontSubsurfaceDistortion, _BackSubsurfaceDistortion;
			float _FrontSSSIntensity, _HeightCorrection, _FoamIntensity, _CausticIntensity;
			CBUFFER_END

			TEXTURECUBE(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURECUBE(_Skybox);
			SAMPLER(sampler_Skybox);
			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);
			TEXTURE2D(_FoamNoiseTex);
			SAMPLER(sampler_FoamNoiseTex);
			TEXTURE2D(_CausticTex);
			SAMPLER(sampler_CausticTex);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);

			v2f vert(a2v v)
			{
				v2f o;
				float3 tangent = float3(1, 0, 0);
				float3 binormal = float3(0, 0, 1);
				float3 p = v.positionOS;

				p += GerstnerWave(_WaveA, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveB, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveC, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveD, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveE, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveF, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveG, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveH, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveI, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveJ, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveK, v.positionOS.xyz, tangent, binormal);
				p += GerstnerWave(_WaveL, v.positionOS.xyz, tangent, binormal);

				o.heightOS = p.y;
				float3 normal = normalize(cross(binormal, tangent));

				VertexPositionInputs positionInputs = GetVertexPositionInputs(p);
				o.positionCS = positionInputs.positionCS;
				o.positionWS = positionInputs.positionWS;

				VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(normal, float4(tangent, 1));
				o.normalWS = vertexNormalInput.normalWS;
				o.tangentWS = vertexNormalInput.tangentWS;
				o.scrPos = ComputeScreenPos(o.positionCS);
				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				o.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);

				return o;
			}
			ENDHLSL
		}
	}
}