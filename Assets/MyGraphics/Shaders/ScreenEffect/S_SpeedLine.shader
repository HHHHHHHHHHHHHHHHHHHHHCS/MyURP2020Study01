Shader "MyRP/ScreenEffect//S_SpeedLine"
{
	Properties
	{
		[NoScaleOffset]_NoiseTex ("NoiseTex", 2D) = "white" { }
		_Center ("Center", Vector) = (0.5, 0.5, 0, 0)
		_RotateSpeed ("Rotate Speed", Range(0,5)) = 0.2
		_RayMultiply ("RayMultiply", Range(0.001, 50)) = 7.5
		_RayPower ("RayPower", Range(0, 50)) = 3.22
		_Threshold ("Threshold", Range(0, 1)) = 1
		_TintColor ("Tint Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		ZTest Always
		ZWrite Off
		Cull Off

		Pass
		{
			Name "Speed Line"

			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				uint vertexID :SV_VertexID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);

			half4 _Center;
			half _RotateSpeed;
			half _RayMultiply;
			half _RayPower;
			half _Threshold;
			half4 _TintColor;


			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;

				uv = uv - _Center.xy;

				half angle = radians(_RotateSpeed * _Time.y);

				half sinAngle, cosAngle;
				sincos(angle, sinAngle, cosAngle);

				float2x2 rotateMatrix0 = float2x2(cosAngle, -sinAngle, sinAngle, cosAngle);
				float2 normalizedUV0 = normalize(mul(rotateMatrix0, uv));

				float2x2 rotateMatrix1 = float2x2(cosAngle, sinAngle, -sinAngle, cosAngle);
				float2 normalizedUV1 = normalize(mul(rotateMatrix1, uv));

				half textureMask = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, normalizedUV0).r
					* SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, normalizedUV1).r;

				half uvMask = PositivePow(_RayMultiply * length(uv), _RayPower);
				half mask = smoothstep(_Threshold - 0.1, _Threshold + 0.1, textureMask * uvMask);

				return half4(_TintColor.rgb, mask * _TintColor.a);
			}
			ENDHLSL
		}
	}
}