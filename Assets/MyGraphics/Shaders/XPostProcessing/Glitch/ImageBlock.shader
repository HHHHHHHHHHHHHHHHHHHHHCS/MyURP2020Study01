Shader "MyRP/XPostProcessing/Glitch/ImageBlock"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"

	uniform float3 _Params;
	uniform float4 _Params2;
	uniform float3 _Params3;

	#define _TimeX _Params.x
	#define _Offset _Params.y
	#define _Fade _Params.z

	#define _BlockLayer1_U _Params2.x
	#define _BlockLayer1_V _Params2.y
	#define _BlockLayer2_U _Params2.z
	#define _BlockLayer2_V _Params2.w

	#define _RGBSplit_Intensity _Params3.x
	#define _BlockLayer1_Intensity _Params3.y
	#define _BlockLayer2_Intensity _Params3.z
	ENDHLSL

	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Blend One Zero

		//0.normal
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;
				float timeX = _TimeX;

				//求解第一层blockLayer
				float2 blockLayer1 = floor(uv * float2(_BlockLayer1_U,_BlockLayer1_V));
				float2 blockLayer2 = floor(uv * float2(_BlockLayer2_U,_BlockLayer2_V));

				// return float4(blockLayer1, blockLayer2);

				float lineNoise1 = pow(RandomNoise(timeX, blockLayer1),_BlockLayer1_Intensity);
				float lineNoise2 = pow(RandomNoise(timeX, blockLayer2),_BlockLayer2_Intensity);
				float rgbSplitNoise = pow(RandomNoise(timeX, 5.1379), 7.1) * _RGBSplit_Intensity;
				float lineNoise = lineNoise1 * lineNoise2 * _Offset - rgbSplitNoise;

				half4 colorR = SampleSrcTex(uv);
				half4 colorG = SampleSrcTex(uv + float2(lineNoise * 0.05 * RandomNoise(timeX, 7.0), 0));
				half4 colorB = SampleSrcTex(uv - float2(lineNoise * 0.05 * RandomNoise(timeX, 23.0), 0));

				half4 result = half4(half3(colorR.r, colorG.g, colorB.b), 1);//0.333333 * (colorR.a + colorG.a + colorB.a));
				result = lerp(colorR, result,_Fade);

				return result;
			}
			ENDHLSL
		}


		//1.debug
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;
				float timeX = _TimeX;

				float2 blockLayer1 = floor(uv * float2(_BlockLayer1_U,_BlockLayer1_V));
				float2 blockLayer2 = floor(uv * float2(_BlockLayer2_U,_BlockLayer2_V));

				float lineNoise1 = pow(RandomNoise(timeX, blockLayer1),_BlockLayer1_Intensity);
				float lineNoise2 = pow(RandomNoise(timeX, blockLayer2),_BlockLayer2_Intensity);
				float rgbSplitNoise = pow(RandomNoise(timeX, 5.1379), 7.1) * _RGBSplit_Intensity;

				float lineNoise = lineNoise1 * lineNoise2 * _Offset - rgbSplitNoise;

				return half4(lineNoise.xxx, 1);
			}
			ENDHLSL
		}
	}
}