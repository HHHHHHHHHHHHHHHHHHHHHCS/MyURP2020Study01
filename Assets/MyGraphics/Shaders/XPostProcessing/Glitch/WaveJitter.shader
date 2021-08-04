Shader "MyRP/XPostProcessing/Glitch/WaveJitter"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"
	#include "../XNoiseLibrary.hlsl"

	#pragma shader_feature USING_FREQUENCY_INFINITE

	uniform float4 _Params;

	#define _Frequency _Params.x
	#define _RGBSplit _Params.y
	#define _Speed _Params.z
	#define _Amount _Params.w
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Blend One Zero

		//0.Horizontal
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;
				float2 resolution = _ScreenParams.xy;
				float time = _Time.y;

				half strength = 0.0;
				#if USING_FREQUENCY_INFINITE
					strength = 1;
				#else
				strength = 0.5 + 0.5 * cos(_Time.y * _Frequency);
				#endif

				//prepare uv
				float uv_y = uv.y * resolution.y;
				float noise_wave_1 = snoise(float2(uv_y * 0.01, time * _Speed * 20)) * (strength * _Amount * 32.0);
				float noise_wave_2 = snoise(float2(uv_y * 0.02, time * _Speed * 10)) * (strength * _Amount * 4.0);
				float noise_wave_x = noise_wave_1 * noise_wave_2 / resolution.x;
				float uv_x = uv.x + noise_wave_x;

				float rgbSplit_uv_x = (_RGBSplit * 50 + (20.0 * strength + 10)) * noise_wave_x / resolution.x;

				//sample RGB color
				half4 colorG = SampleSrcTex(float2(uv_x, uv.y));
				half4 colorRB = SampleSrcTex(float2(uv_x + rgbSplit_uv_x, uv.y));

				return half4(colorRB.r, colorG.g, colorRB.b, 1); //0.5 * (colorRB.a + colorG.a));
			}
			ENDHLSL
		}

		//1.Vertical
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;
				float2 resolution = _ScreenParams.xy;
				float time = _Time.y;

				half strength = 0.0;
				#if USING_FREQUENCY_INFINITE
					strength = 1;
				#else
				strength = 0.5 + 0.5 * cos(_Time.y * _Frequency);
				#endif

				//prepare uv
				float uv_x = uv.x * resolution.x;
				float noise_wave_1 = snoise(float2(uv_x * 0.01, time * _Speed * 20)) * (strength * _Amount * 32.0);
				float noise_wave_2 = snoise(float2(uv_x * 0.02, time * _Speed * 10)) * (strength * _Amount * 4.0);
				float noise_wave_y = noise_wave_1 * noise_wave_2 / resolution.x;
				float uv_y = uv.y + noise_wave_y;

				float rgbSplit_uv_y = (_RGBSplit * 50 + (20.0 * strength + 10)) * noise_wave_y / resolution.y;

				//sample RGB color
				half4 colorG = SampleSrcTex(float2(uv.x, uv_y));
				half4 colorRB = SampleSrcTex(float2(uv.x, uv_y + rgbSplit_uv_y));

				return half4(colorRB.r, colorG.g, colorRB.b, 1); //0.5 * (colorRB.a + colorG.a));
			}
			ENDHLSL
		}
	}
}