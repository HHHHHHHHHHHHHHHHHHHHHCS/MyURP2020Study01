Shader "MyRP/XPostProcessing/Glitch/LineBlock"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"

	uniform half4 _Params;
	uniform half4 _Params2;

	#define _Frequency _Params.x
	#define _TimeX _Params.y
	#define _Amount _Params.z
	#define _Offset _Params2.x
	#define _LinesWidth _Params2.y
	#define _Alpha _Params2.z

	float3 RGB2YUV(float3 rgb)
	{
		float3 yuv;
		yuv.x = dot(rgb, float3(0.299, 0.587, 0.114));
		yuv.y = dot(rgb, float3(-0.14713, -0.28886, 0.436));
		yuv.z = dot(rgb, float3(0.615, -0.51499, -0.10001));
		return yuv;
	}

	float3 YUV2RGB(float3 yuv)
	{
		float3 rgb;
		rgb.r = yuv.x + yuv.z * 1.13983;
		rgb.g = yuv.x + dot(float2(-0.39465, -0.58060), yuv.yz);
		rgb.b = yuv.x + yuv.y * 2.03211;
		return rgb;
	}
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

			#pragma shader_feature USING_FREQUENCY_INFINITE

			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;

				// _TimeX *= fmod(_Time.y, 100.0);

				half strength = 0;

				#if USING_FREQUENCY_INFINITE
				strength = 10;
				#else
				strength = 0.5+ 0.5 * cos(_TimeX * _Frequency);
				#endif

				_TimeX *= strength;

				//1.生成随机强度梯度线条
				float truncTime = Trunc(_TimeX, 4.0);
				float uv_trunc = RandomNoise(Trunc(uv.yy, 8).xx + 100 * truncTime);
				float uv_randomTrunc = 6.0 * Trunc(_TimeX, 24.0 * uv_trunc);

				//2.生成随机非均匀宽度线条
				float blockLine_random = 0.5 * RandomNoise(Trunc(uv.yy + uv_randomTrunc,
				                                                 float2(8 * _LinesWidth, 8 * _LinesWidth)));
				blockLine_random += 0.5 * RandomNoise(Trunc(uv.yy + uv_randomTrunc, float2(7, 7)));
				blockLine_random = blockLine_random * 2.0 - 1.0;
				blockLine_random = sign(blockLine_random) * saturate((abs(blockLine_random) - _Amount) / 0.4);
				blockLine_random = lerp(0, blockLine_random,_Offset);

				//3.生成源色调的BlockLine Glitch
				float2 uv_blockLine = uv;
				uv_blockLine = saturate(uv_blockLine + float2(0.1 * blockLine_random, 0));
				half4 blockLineColor = SampleSrcTex(abs(uv_blockLine));

				//4.将RGB转到YUV空间,并做色调偏移
				//rgb->yuv
				half3 blockLineColor_yuv = RGB2YUV(blockLineColor.rgb);
				//adjust chrominance | 色度
				blockLineColor_yuv.y /= 1.0 - 3.0 * abs(blockLine_random) * saturate(0.5 - blockLine_random);
				//adjust chroma | 浓度
				blockLineColor_yuv.z += 0.125 * blockLine_random * saturate(blockLine_random - 0.5);
				half3 blockLineColor_rgb = YUV2RGB(blockLineColor_yuv);

				//5.与源场景图进行混合
				half4 sceneColor = SampleSrcTex(uv);

				return lerp(sceneColor, half4(blockLineColor_rgb, blockLineColor.a),_Alpha);
			}
			ENDHLSL
		}

		//0.Vertical
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature USING_FREQUENCY_INFINITE

			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;

				// _TimeX *= fmod(_Time.y, 100.0);

				half strength = 0;

				#if USING_FREQUENCY_INFINITE
				strength = 10;
				#else
				strength = 0.5+ 0.5 * cos(_TimeX * _Frequency);
				#endif

				_TimeX *= strength;

				//1.生成随机强度梯度线条
				float truncTime = Trunc(_TimeX, 4.0);
				float uv_trunc = RandomNoise(Trunc(uv.xx, 8).xx + 100 * truncTime);
				float uv_randomTrunc = 6.0 * Trunc(_TimeX, 24.0 * uv_trunc);

				//2.生成随机非均匀宽度线条
				float blockLine_random = 0.5 * RandomNoise(Trunc(uv.xx + uv_randomTrunc,
				                                                 float2(8 * _LinesWidth, 8 * _LinesWidth)));
				blockLine_random += 0.5 * RandomNoise(Trunc(uv.xx + uv_randomTrunc, float2(7, 7)));
				blockLine_random = blockLine_random * 2.0 - 1.0;
				blockLine_random = sign(blockLine_random) * saturate((abs(blockLine_random) - _Amount) / 0.4);
				blockLine_random = lerp(0, blockLine_random,_Offset);

				//3.生成源色调的BlockLine Glitch
				float2 uv_blockLine = uv;
				uv_blockLine = saturate(uv_blockLine + float2(0.1 * blockLine_random, 0));
				half4 blockLineColor = SampleSrcTex(abs(uv_blockLine));

				//4.将RGB转到YUV空间,并做色调偏移
				//rgb->yuv
				half3 blockLineColor_yuv = RGB2YUV(blockLineColor.rgb);
				//adjust chrominance | 色度
				blockLineColor_yuv.y /= 1.0 - 3.0 * abs(blockLine_random) * saturate(0.5 - blockLine_random);
				//adjust chroma | 浓度
				blockLineColor_yuv.z += 0.125 * blockLine_random * saturate(blockLine_random - 0.5);
				half3 blockLineColor_rgb = YUV2RGB(blockLineColor_yuv);

				//5.与源场景图进行混合
				half4 sceneColor = SampleSrcTex(uv);

				return lerp(sceneColor, half4(blockLineColor_rgb, blockLineColor.a),_Alpha);
			}
			ENDHLSL
		}
	}
}