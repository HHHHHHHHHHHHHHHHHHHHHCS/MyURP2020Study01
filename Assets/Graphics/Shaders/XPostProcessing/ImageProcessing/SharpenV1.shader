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

			float _Strength;
			float _Threshold;

			half4 DoEffect(v2f IN)
			{
				float2 pixelSize = _ScreenParams.zw - 1;
				float2 halfPixelSize = pixelSize * 0.5;

				half4 blur = SampleSrcTex(IN.uv + float2(halfPixelSize.x, -pixelSize.y));
				blur += SampleSrcTex(IN.uv + float2(-pixelSize.x, -halfPixelSize.y));
				blur += SampleSrcTex(IN.uv + float2(pixelSize.x, -halfPixelSize.y));
				blur += SampleSrcTex(IN.uv + float2(-halfPixelSize.x, pixelSize.y));
				blur *= 0.25;

				half4 sceneColor = SampleSrcTex(IN.uv);
				half4 sharp = _Strength * (sceneColor - blur);

				sceneColor.rgb += clamp(Luminance(sharp), -_Threshold, _Threshold);

				return sceneColor;
			}
			ENDHLSL
		}

	}
}