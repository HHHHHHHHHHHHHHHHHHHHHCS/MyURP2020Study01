Shader "MyRP/XPostProcessing/ImageProcessing/SharpenV1"
{
	Properties
	{
	}
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Blend One Zero

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "../XPostProcessingLib.hlsl"

			float _Sharpness;

			half4 DoEffect(v2f IN)
			{
				float2 pixelSize = 1.5 * (_ScreenParams.zw - 1);
				float4 offsetUV = float4(IN.uv + pixelSize, IN.uv - pixelSize);

				half4 blur = SampleSrcTex(offsetUV.xy);
				blur += SampleSrcTex(offsetUV.xw);
				blur += SampleSrcTex(offsetUV.zy);
				blur += SampleSrcTex(offsetUV.zw);
				blur *= 0.25;

				half4 sceneColor = SampleSrcTex(IN.uv);

				return sceneColor + (sceneColor - blur) * _Sharpness;
			}
			ENDHLSL
		}

	}
}