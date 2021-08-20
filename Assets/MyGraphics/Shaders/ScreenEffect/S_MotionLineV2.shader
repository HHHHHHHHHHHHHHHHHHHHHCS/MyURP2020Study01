//https://www.shadertoy.com/view/3ll3z2
Shader "MyRP/ScreenEffect/S_MotionLineV2"
{
	Properties
	{
	}

	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "MotionLineV2"
			ZTest Always
			ZWrite Off
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				uint vertexID:SV_VertexID;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			TEXTURE2D(_SrcTex);

			SAMPLER(s_linear_clamp_sampler);

			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}


			half4 frag(v2f IN) : SV_Target
			{
				float2 U = IN.uv;
				float2 D = cos(.3 * _Time.y * 0 + 3 - float2(0, HALF_PI)); // custom dir

				U = 2.0 * U - 1;

				half4 O = SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, IN.uv);

				float t = 10. * _Time.y;
				float kl = 50.; // wavelenght
				float b = .5 - .5 * cos(6.28 * Luminance(O)); // border zone (where effect occurs)
				float x = dot(U, D); // pos along D
				float phi = kl * x;


				O += .25 * b * sin(phi - t); // magic draw
				return O;
			}
			ENDHLSL
		}

	}
}