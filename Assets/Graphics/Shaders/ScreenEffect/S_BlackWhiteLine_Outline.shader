Shader "MyRP/ScreenEffect/S_BlackWhiteLine_Outline"
{
	Properties
	{
		[Header(Edge)] _EdgeWidth("Edge Width", Range(0.05,5)) = 0.3
		_EdgeColor("Edge Color", Color) = (0, 0, 0, 1)
		[Header(Background)] _BackgroundColor("Bakcground Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "BlackWhiteLine Outline"
			ZTest Always
			ZWrite Off
			Cull Off


			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
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

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_point_clamp_sampler);
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			TEXTURE2D(_SrcTex);

			half _EdgeWidth;
			half3 _EdgeColor;
			half3 _BackgroundColor;

			half4 SampleSrcTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
			}

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

			half4 Outline(float2 uv)
			{
				half4 sceneColor = SampleSrcTex(uv);


				float outlineFade = Scharr(_EdgeWidth / _ScreenParams.x, _EdgeWidth / _ScreenParams.y, uv);

				//background fading
				sceneColor.rgb = lerp(sceneColor.rgb, _BackgroundColor, 1);
				//edge opacity
				sceneColor.rgb = lerp(_BackgroundColor, _EdgeColor, outlineFade);

				return sceneColor;
			}

			v2f vert(a2v IN)
			{
				v2f o;
				o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
				o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
				return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
				return Outline(IN.uv);
			}
			ENDHLSL
		}
	}
}