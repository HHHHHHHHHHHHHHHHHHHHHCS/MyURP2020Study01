Shader "MyRP/XPostProcessing/Glitch/ImageBlockV4"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"

	uniform float4 _Params;

	#define _Speed _Params.x
	#define _BlockSize _Params.y
	#define _MaxRGBSplitX _Params.z
	#define _MaxRGBSplitY _Params.w
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
				float time = _Time.y;

				half2 block = RandomNoise(time, floor(uv * _BlockSize),_Speed).xx;

				float displaceNoise = pow(block.x, 11.0); //pow(block.x, 8.0) * pow(block.x, 3.0);
				float splitRGBNoise = pow(RandomNoise(time, 7.2341,_Speed), 17.0);
				float offsetX = displaceNoise - splitRGBNoise * _MaxRGBSplitX;
				float offsetY = displaceNoise - splitRGBNoise * _MaxRGBSplitY;

				float noiseX = 0.05 * RandomNoise(time, 13.0,_Speed);
				float noiseY = 0.05 * RandomNoise(time, 7.0,_Speed);
				float2 offset = float2(offsetX * noiseX, offsetY * noiseY);

				half4 colorR = SampleSrcTex(uv);
				half4 colorG = SampleSrcTex(uv + offset);
				half4 colorB = SampleSrcTex(uv - offset);

				half4 result = half4(half3(colorR.r, colorG.g, colorB.b), 1);//0.333333 * (colorR.a + colorG.a + colorB.a));

				return result;
			}
			ENDHLSL
		}
	}
}