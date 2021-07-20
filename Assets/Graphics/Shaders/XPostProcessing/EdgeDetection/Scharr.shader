Shader "MyRP/XPostProcessing/Glitch/Scharr"
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

			half2 _Params;
			half3 _EdgeColor;
			half3 _BackgroundColor;

			#define _EdgeWidth _Params.x
			#define _BackgroundFade _Params.y

			inline float Intensity(in half3 col)
			{
				return sqrt(dot(col, col));
			}

			inline float Intensity(in half4 col)
			{
				return Intensity(col.rgb);
			}

			float Scharr(float stepX, float stepY, float2 center)
			{
				float topLeft = Intensity(SampleSrcTex(center + float2(-stepX, stepY)));
				float midLeft = Intensity(SampleSrcTex(center + float2(-stepX, 0)));
				float bottomLeft = Intensity(SampleSrcTex(center + float2(-stepX, -stepY)));
				float midTop = Intensity(SampleSrcTex(center + float2(0, stepY)));
				float midBottom = Intensity(SampleSrcTex(center + float2(0, -stepY)));
				float topRight = Intensity(SampleSrcTex(center + float2(stepX, stepY)));
				float midRight = Intensity(SampleSrcTex(center + float2(stepX, 0)));
				float bottomRight = Intensity(SampleSrcTex(center + float2(stepX, -stepY)));

				// scharr masks ( http://en.wikipedia.org/wiki/Sobel_operator#Alternative_operators)
				//        3 0 -3        3 10   3
				//    X = 10 0 -10  Y = 0  0   0
				//        3 0 -3        -3 -10 -3

				// Gx = sum(kernelX[i][j]*image[i][j]);
				float Gx = 3.0 * topLeft + 10.0 * midLeft + 3.0 * bottomLeft
					- 3.0 * topRight - 10.0 * midRight - 3.0 * bottomRight;
				// Gy = sum(kernelY[i][j]*image[i][j]);
				float Gy = 3.0 * topLeft + 10.0 * midTop + 3.0 * topRight
					- 3.0 * bottomLeft - 10.0 * midBottom - 3.0 * bottomRight;

				float scharrGradient = sqrt((Gx * Gx) + (Gy * Gy));
				return scharrGradient;
			}

			half4 DoEffect(v2f IN)
			{
				half4 sceneColor = SampleSrcTex(IN.uv);

				float scharrGradient = Scharr(_EdgeWidth / _ScreenParams.x,_EdgeWidth / _ScreenParams.y, IN.uv);

				// return sceneColor * scharrGradient;

				//background fading
				sceneColor.rgb = lerp(sceneColor.rgb, _BackgroundColor, _BackgroundFade);
				//edge opacity
				sceneColor.rgb = lerp(sceneColor.rgb, _EdgeColor, scharrGradient);

				return sceneColor;
			}
			ENDHLSL
		}
	}
}