Shader "MyRP/ScreenEffect/S_GlitchShake"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl", Range(0, 1)) = 0.5
		//色块分离
		_Speed("Speed", Range(0, 1.0)) = 0.5
		_Amount("Amount", Range(0, 10)) = 1
		_Fade("Fade", Range(0, 1.0)) = 1
		_BlockLayer1_U("BlockLayer1 U", Range(0, 50)) = 9
		_BlockLayer1_V("BlockLayer1 V", Range(0, 50)) = 9
		_BlockLayer1_Intensity("BlockLayer1 Intensity", Range(0, 50)) = 8
		_BlockLayer2_U("BlockLayer2 U", Range(0, 50)) = 5
		_BlockLayer2_V("BlockLayer2 V", Range(0, 50)) = 5
		_BlockLayer2_Intensity("BlockLayer2 Intensity", Range(0, 50)) = 4
		_RGBSplit_Intensity("RGB Split Intensity", Range(0, 1)) = 0.5

		//颜色分离
		_CenterX("Center X", Range(0, 1.0)) = 0.5
		_CenterY("Center Y", Range(0, 1.0)) = 0.5
		_MaxScale("Max Scale",Range(0, 1.0)) = 0.3
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
			Name "Glitch Shake"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

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

			float _ProgressCtrl;

			float _Speed;
			float _Amount;
			float _Fade;
			float _BlockLayer1_U;
			float _BlockLayer1_V;
			float _BlockLayer1_Intensity;
			float _BlockLayer2_U;
			float _BlockLayer2_V;
			float _BlockLayer2_Intensity;
			float _RGBSplit_Intensity;

			float _CenterX;
			float _CenterY;
			float _MaxScale;

			inline half4 SampleSrcTex(float2 uv)
			{
				return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
			}

			inline float CalcT(float ctrl)
			{
				float a = 1.5 * ctrl - 0.5;
				float y = -a * a + 1;
				return y;
			}

			inline float RandomNoise(float time, float2 seed)
			{
				return frac(sin(dot(seed * floor(time * 30.0), float2(127.1, 311.7))) * 43758.5453123);
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
				float2 uv = IN.uv;
				float ctrl = _ProgressCtrl; // _Time.y;
				float2 center = float2(_CenterX, _CenterY);
				float t = CalcT(ctrl);

				half3 color = SampleSrcTex(uv).rgb;

				//其实可以去掉这行  但是这里为了测试
				if (ctrl <= 0 || ctrl >= 1)
				{
					return half4(color, 1);
				}

				//色块偏离
				//---------------------

				float timeX = ctrl * _Speed;

				//求解第一层blockLayer
				float2 blockLayer1 = floor(uv * float2(_BlockLayer1_U, _BlockLayer1_V));
				float2 blockLayer2 = floor(uv * float2(_BlockLayer2_U, _BlockLayer2_V));

				// return float4(blockLayer1, blockLayer2);

				float lineNoise1 = pow(RandomNoise(timeX, blockLayer1), _BlockLayer1_Intensity);
				float lineNoise2 = pow(RandomNoise(timeX, blockLayer2), _BlockLayer2_Intensity);
				float rgbSplitNoise = pow(RandomNoise(timeX, 5.1379), 7.1) * _RGBSplit_Intensity;
				float lineNoise = lineNoise1 * lineNoise2 * (1 + t) * _Amount - rgbSplitNoise;

				float offsetX = lineNoise * 0.05 * RandomNoise(timeX, 7.0);
				float offsetY = lineNoise * 0.05 * RandomNoise(timeX, 23.0);

				uv -= t * float2(offsetX, offsetY);

				//RGB Color 分离
				//--------------
				float2 uvR = (uv - center) * (1 - _MaxScale * t) + center;
				half colorR = SampleSrcTex(uvR).r;
				float2 uvG = (uv - center) * (1 - _MaxScale * t * 0.8) + center;
				half colorG = SampleSrcTex(uvG).g;
				float2 uvB = (uv - center) * (1 - _MaxScale * t * 0.6) + center;
				half colorB = SampleSrcTex(uvB).b;

				half3 finalColor = half3(colorR, colorG, colorB);

				finalColor = lerp(finalColor, color, 1 - 0.4 * t);

				return half4(finalColor, 1);
			}
			ENDHLSL
		}
	}
}