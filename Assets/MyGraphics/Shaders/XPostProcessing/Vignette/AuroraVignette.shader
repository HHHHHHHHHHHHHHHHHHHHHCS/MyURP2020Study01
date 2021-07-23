Shader "MyRP/XPostProcessing/Vignette/AuroraVignette"
{
	Properties
	{
	}
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		Blend SrcAlpha OneMinusSrcAlpha , Zero One

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "../XPostProcessingLib.hlsl"

			float _VignetteArea;
			float _VignetteSmothness;
			float _ColorChange;
			half4 _Color;
			float _TimeX;
			half3 _ColorFactor;
			float _Fading;

			half4 DoEffect(v2f IN)
			{
				float2 uv = IN.uv;
				float2 uv0 = uv - float2(0.5 + 0.5 * sin(1.4 * TWO_PI * uv.x + 2.8 * _TimeX), 0.5);
				float3 wave = float3(0.5 * (cos(sqrt(dot(uv0, uv0)) * 5.6) + 1.0), cos(4.62 * dot(uv, uv) + _TimeX),
				                     cos(distance(uv, float2(1.6 * cos(_TimeX * 2.0), 1.0 * sin(_TimeX * 1.7))) * 1.3));
				half waveFactor = 1.28 * dot(wave, _ColorFactor) / _ColorChange;
				half vignetteIntensity = 1.0 - smoothstep(_VignetteArea, _VignetteArea - 0.05 - _VignetteSmothness,
				                                          length(float2(0.5, 0.5) - uv));
				half3 auroraColor = half3
				(
					_ColorFactor.r * 0.5 * (sin(waveFactor + _TimeX * 3.45) + 1.0),
					_ColorFactor.g * 0.5 * (sin(waveFactor + _TimeX * 3.15) + 1.0),
					_ColorFactor.b * 0.4 * (sin(waveFactor + _TimeX * 1.26) + 1.0)
				);

				return half4(auroraColor, vignetteIntensity * _Fading);
			}
			ENDHLSL
		}

	}
}