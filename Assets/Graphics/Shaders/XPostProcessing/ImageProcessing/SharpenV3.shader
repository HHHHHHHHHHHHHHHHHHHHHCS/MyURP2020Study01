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

			float _CentralFactor;
			float _SideFactor;


			half4 DoEffect(v2f IN)
			{
				float2 pixelSize = 1.5 * (_ScreenParams.zw - 1);
				float4 offsetUV = float4(IN.uv + pixelSize, IN.uv - pixelSize);

				half4 col = SampleSrcTex(IN.uv) * _CentralFactor;
				col -= SampleSrcTex(offsetUV.xy) * _SideFactor;
				col -= SampleSrcTex(offsetUV.xw) * _SideFactor;
				col -= SampleSrcTex(offsetUV.zy) * _SideFactor;
				col -= SampleSrcTex(offsetUV.zw) * _SideFactor;


				return col;
			}
			ENDHLSL
		}

	}
}