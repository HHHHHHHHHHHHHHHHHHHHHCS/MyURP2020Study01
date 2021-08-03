Shader "MyRP/XPostProcessing/Glitch/RGBSplitV5"
{
	Properties
	{
	}
	HLSLINCLUDE
	#include "../XPostProcessingLib.hlsl"

	uniform float2 _Params;

	#define _Amplitude _Params.x
	#define _Speed _Params.y
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

				float4 splitAmount = Pow4(SampleNoiseTex(float2(_Speed * time, 2.0 * _Speed * time/ 25.0)), 8.0)
					* float4(_Amplitude, _Amplitude, _Amplitude, 1.0);

				splitAmount *= 2.0 * splitAmount.w - 1.0;

				half colorR = SampleSrcTex(uv + float2(splitAmount.x, -splitAmount.y)).r;
				half colorG = SampleSrcTex(uv + float2(splitAmount.y, -splitAmount.z)).g;
				half colorB = SampleSrcTex(uv + float2(splitAmount.z, -splitAmount.x)).b;

				half3 finalColor = half3(colorR, colorG, colorB);
				return half4(finalColor, 1);
			}
			ENDHLSL
		}
	}
}