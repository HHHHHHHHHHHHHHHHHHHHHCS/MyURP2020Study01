Shader "MyRP/Skinner/TrailSurface"
{
	Properties
	{
		_Albedo("Albedo", Color) = (0.5, 0.5, 0.5)
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		_Metallic("Metallic", Range(0, 1)) = 0

		[Header(Self Illumination)]
		_BaseHue("Base Hue", Range(0, 1)) = 0
		_HueRandomness("Hue Randomness", Range(0, 1)) = 0.2
		_Saturation("Saturation", Range(0, 1)) = 1
		_Brightness("Brightness", Range(0, 6)) = 0.8
		_EmissionProb("Probability", Range(0, 1)) = 0.2

		[Header(Color Modifier (By Speed))]
		_CutoffSpeed("Cutoff Speed", Float) = 0.5
		_SpeedToIntensity("Sensitivity", Float) = 1
		_BrightnessOffs("Brightness Offset", Range(0, 6)) = 1.0
		_HueShift("Hue Shift", Range(-1, 1)) = 0.2
	}
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "SkinnerCommon.hlsl"

	TEXTURE2D(_PositionBuffer);
	TEXTURE2D(_VelocityBuffer);
	TEXTURE2D(_OrthnormBuffer);


	SAMPLER(s_linear_clamp_sampler);

	// Line width modifier
	half3 _LineWidth; // (max width, cutoff, speed-to-width / max width)

	void GetPosAndNormal(float4 vertex, out float4 pos, out float3 nor, out float speed)
	{
		//fetch samples from the animation kernel
		float2 uv = vertex.xy;
		float3 p = SAMPLE_TEXTURE2D_LOD(_PositionBuffer, s_linear_clamp_sampler, uv, 0).xyz;
		float3 v = SAMPLE_TEXTURE2D_LOD(_VelocityBuffer, s_linear_clamp_sampler, uv, 0).xyz;
		float4 b = SAMPLE_TEXTURE2D_LOD(_OrthnormBuffer, s_linear_clamp_sampler, uv, 0);

		// Extract normal/binormal vector from the orthnormal sample.
		half3 normal = StereoInverseProjection(b.xy);
		half3 binormal = StereoInverseProjection(b.zw);

		speed = length(v);

		half width = _LineWidth.x * vertex.z * (1 - vertex.y);
		width *= saturate((speed - _LineWidth.y) * _LineWidth.z);

		pos = float4(p + binormal * width, vertex.w);
		nor = normal;
		// pos = vertex;
	}
	ENDHLSL

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "Geometry"
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


			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON

			// Keywords
			#pragma multi_compile _ _SCREEN_SPACE_OCCLUSION
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE


			// Base material properties
			half3 _Albedo;
			half _Smoothness;
			half _Metallic;

			// Color modifier
			half _CutoffSpeed;
			half _SpeedToIntensity;

			struct a2v
			{
				float4 vertex:POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				half3 color : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float4 shadowCoord : TEXCOORD3;
				float3 sh : TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			v2f vert(a2v IN)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_TRANSFER_INSTANCE_ID(IN, o);

				float id = IN.vertex.x;

				float4 vpos;
				float3 nor;
				float speed;
				GetPosAndNormal(IN.vertex, vpos, nor, speed);

				half intensity = saturate((speed - _CutoffSpeed) * _SpeedToIntensity);


				o.worldPos = TransformObjectToWorld(vpos.xyz);
				o.pos = TransformWorldToHClip(o.worldPos);
				o.worldNormal = TransformObjectToWorldNormal(nor);
				o.color = ColorAnimation(id, intensity);
				o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
				OUTPUT_SH(o.worldNormal, o.sh);
				return o;
			}


			half4 frag(v2f IN, half facing : VFACE):SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(IN);

				float3 normalWS = float3(0, 0, facing > 0 ? 1 : -1);// normalize(IN.worldNormal);
				normalWS = TransformObjectToWorldNormal(normalWS);
				half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.worldPos));

				InputData inputData = (InputData)0;
				//PRDFForward.BuildInputData()
				inputData.positionWS = IN.worldPos;
				inputData.normalWS = normalWS; 
				inputData.viewDirectionWS = viewDirectionWS;
				inputData.shadowCoord = IN.shadowCoord;
				inputData.fogCoord = 0;
				inputData.vertexLighting = 1;
				inputData.bakedGI = SAMPLE_GI(0, IN.sh, IN.worldNormal);
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.pos);

				SurfaceData surface = (SurfaceData)0;
				surface.albedo = _Albedo;
				surface.metallic = _Metallic;
				surface.specular = 0;
				surface.smoothness = _Smoothness;
				surface.occlusion = 1.0;
				surface.emission = IN.color;
				surface.alpha = 1;
				surface.clearCoatMask = 0;
				surface.clearCoatSmoothness = 1;

				half4 color = UniversalFragmentPBR(inputData, surface);
				return color;
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

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON


			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

			struct a2v
			{
				float4 vertex: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 positionCS: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};


			// x: global clip space bias, y: normal world space bias
			float3 _LightDirection;


			v2f vert(a2v v)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float4 vpos;
				float3 nor;
				float speed;
				GetPosAndNormal(v.vertex, vpos, nor, speed);

				float3 positionWS = TransformObjectToWorld(vpos.xyz);
				float3 normalWS = TransformObjectToWorldNormal(nor.xyz, true);
				o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

				return o;
			}

			float4 frag(v2f IN): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(IN);

				return 0;
			}
			ENDHLSL

		}

		Pass
		{
			Name "DepthOnly"
			Tags
			{
				"LightMode" = "DepthOnly"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				float4 vertex: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float4 positionCS: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};


			v2f vert(a2v IN)
			{
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float4 vpos;
				float3 nor;
				float speed;
				GetPosAndNormal(IN.vertex, vpos, nor, speed);
				
				float3 positionWS = TransformObjectToWorld(IN.vertex.xyz);
				o.positionCS = TransformWorldToHClip(positionWS);

				return o;
			}

			float4 frag(v2f IN): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(IN);

				return 0;
			}
			ENDHLSL

		}


		Pass
		{
			Tags
			{
				"LightMode" = "MotionVectors"
			}
			Cull Off
			ZWrite Off
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct a2v
			{
				float4 vertex:POSITION;
				float2 texcoord1 :TEXCOORD1;
			};

			struct v2f
			{
				float4 vertex:SV_POSITION;
				float4 transfer0:TEXCOORD0;
				float4 transfer1:TEXCOORD1;
			};

			TEXTURE2D(_PreviousPositionBuffer);
			TEXTURE2D(_PreviousVelocityBuffer);
			TEXTURE2D(_PreviousOrthnormBuffer);

			float4x4 _NonJitteredVP;
			float4x4 _PreviousVP;
			float4x4 _PreviousM;

			v2f vert(a2v IN)
			{
				//fetch samples from the animation kernel
				float2 uv = IN.vertex.xy;
				float3 p0 = SAMPLE_TEXTURE2D_LOD(_PreviousPositionBuffer, s_linear_clamp_sampler, uv, 0).xyz;
				float3 v0 = SAMPLE_TEXTURE2D_LOD(_PreviousVelocityBuffer, s_linear_clamp_sampler, uv, 0).xyz;
				float4 b0 = SAMPLE_TEXTURE2D_LOD(_PreviousOrthnormBuffer, s_linear_clamp_sampler, uv, 0);
				float3 p1 = SAMPLE_TEXTURE2D_LOD(_PositionBuffer, s_linear_clamp_sampler, uv, 0).xyz;
				float3 v1 = SAMPLE_TEXTURE2D_LOD(_VelocityBuffer, s_linear_clamp_sampler, uv, 0).xyz;
				float4 b1 = SAMPLE_TEXTURE2D_LOD(_OrthnormBuffer, s_linear_clamp_sampler, uv, 0);

				//Binormal Vector
				half3 binormal0 = StereoInverseProjection(b0.zw);
				half3 binormal1 = StereoInverseProjection(b1.zw);

				p0 = lerp(p0, p1, 0.5);
				p1 = lerp(v0, v1, 0.5);
				binormal0 = normalize(lerp(binormal0, binormal1, 0.5));

				//Line Width
				half width = _LineWidth.x * IN.vertex.z * (1 - IN.vertex.y);
				half width0 = width * saturate((length(v0) - _LineWidth.y) * _LineWidth.z);
				half width1 = width * saturate((length(v1) - _LineWidth.y) * _LineWidth.z);

				float4 vp0 = float4(p0 + binormal0 * width0, 1);
				float4 vp1 = float4(p1 + binormal1 * width1, 1);

				v2f o;
				o.vertex = TransformObjectToHClip(vp1.xyz);
				o.transfer0 = mul(_PreviousVP, mul(_PreviousM, vp0));
				o.transfer1 = mul(_NonJitteredVP, mul(UNITY_MATRIX_M, vp1));
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				float3 hp0 = IN.transfer0.xyz / IN.transfer0.w;
				float3 hp1 = IN.transfer1.xyz / IN.transfer1.w;

				float2 vp0 = (hp0.xy + 1) / 2.0;
				float2 vp1 = (hp1.xy + 1) / 2.0;

				#if UNITY_UV_STARTS_AT_TOP
				vp0.y = 1 - vp0.y;
				vp1.y = 1 - vp1.y;
				#endif

				return half4(vp1 - vp0, 0, 1);
			}
			ENDHLSL
		}
	}
}