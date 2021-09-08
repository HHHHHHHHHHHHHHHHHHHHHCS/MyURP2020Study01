Shader "MyRP/HologramRim/HologramRim"
{
	Properties
	{
		// General
		_Brightness("Brightness", Range(0.1, 6.0)) = 3.0
		_Alpha ("Alpha", Range (0.0, 1.0)) = 1.0
		_Direction ("Direction", Vector) = (0,1,0,0)
		// Main Color
		_MainTex ("MainTexture", 2D) = "white" {}
		_MainColor ("MainColor", Color) = (1,1,1,1)
		// Rim/Fresnel
		_RimColor ("Rim Color", Color) = (1,1,1,1)
		_RimPower ("Rim Power", Range(0.1, 10)) = 5.0
		// Scanline
		[Toggle(_SCAN_ON)] _ScanToggle("Scan Toggle", Float) = 1
		_ScanTiling ("Scan Tiling", Range(0.01, 10.0)) = 0.05
		_ScanSpeed ("Scan Speed", Range(-2.0, 2.0)) = 1.0
		// Glow
		[Toggle(_GLOW_ON)] _GlowToggle("Glow Toggle", Float) = 1
		_GlowTiling ("Glow Tiling", Range(0.01, 1.0)) = 0.05
		_GlowSpeed ("Glow Speed", Range(-10.0, 10.0)) = 1.0
		// Glitch
		[Toggle(_GLITCH_ON)] _GlitchToggle("Glitch Toggle", Float) = 1
		_GlitchSpeed ("Glitch Speed", Range(0, 50)) = 1.0
		_GlitchIntensity ("Glitch Intensity", Float) = 0
		// Alpha Flicker
		_FlickerTex ("Flicker Control Texture", 2D) = "white" {}
		_FlickerSpeed ("Flicker Speed", Range(0.01, 100)) = 1.0

		// Settings
		[HideInInspector] _Fold("__fld", Float) = 1.0
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature _ _SCAN_ON
			#pragma shader_feature _ _GLOW_ON
			#pragma shader_feature _ _GLITCH_ON

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};


			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
			};


			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;
			TEXTURE2D(_FlickerTex);
			SAMPLER(sampler_FlickerTex);
			float4 _Direction;
			float4 _MainColor;
			float4 _RimColor;
			float _RimPower;
			float _GlitchSpeed;
			float _GlitchIntensity;
			float _Brightness;
			float _Alpha;
			float _ScanTiling;
			float _ScanSpeed;
			float _GlowTiling;
			float _GlowSpeed;
			float _FlickerSpeed;


			v2f vert(a2v IN)
			{
				v2f o;

				#ifdef _GLITCH_ON
					IN.vertex.x += _GlitchIntensity * (step(0.5, sin(_Time.y * 2.0 + IN.vertex.y * 1.0))
								* step(0.99, sin(_Time.y * _GlitchSpeed * 0.5)));
				#endif


				o.worldPos = TransformObjectToWorld(IN.vertex.xyz);
				o.pos = TransformWorldToHClip(o.worldPos);
				o.uv = TRANSFORM_TEX(IN.uv, _MainTex);
				o.viewDir = GetWorldSpaceViewDir(o.worldPos);
				o.worldNormal = TransformObjectToWorldNormal(IN.normal);

				return o;
			}


			half4 frag(v2f IN):SV_Target
			{
				#ifdef _SCAN_ON
				return 1;
				#endif

				return 0;
			}
			ENDHLSL
		}
	}
}