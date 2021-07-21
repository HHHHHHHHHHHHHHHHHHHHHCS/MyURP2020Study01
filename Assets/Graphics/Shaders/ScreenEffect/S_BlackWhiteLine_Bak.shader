Shader "MyRP/ScreenEffect/S_BlackWhiteLine"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl", Range(0, 1)) = 0.5
		_CellCount("Cell Count", Vector) = (50, 200, 0, 0)
		_CellFrequent("Cell Frequent",Range(0.01,10)) = 1
		_ExplodePoint("Explode Point", Vector) = (0, 0, 0, 0)
		_JunctionSoftness("Junction Softness",Range(0,2)) = 1
		_OutlineSoftness("Outline Softness",Range(0,4)) = 2
		_LineNoiseTex("Line Noise Texture", 2D) = "black"{}
		[Header(Edge)] _EdgeWidth("Edge Width", Range(0.05,5)) = 0.3
		_EdgeColor("Edge Color", Color) = (0, 0, 0, 1)
		[Header(Background)] _BackgroundColor("Bakcground Color", Color) = (1, 1, 1, 1)
	}

	HLSLINCLUDE
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
	TEXTURE2D(_SceneTex);
	TEXTURE2D(_LineNoiseTex);
	float4 _LineNoiseTex_ST;

	float _ProgressCtrl;
	float2 _CellCount;
	float _CellFrequent;
	float2 _ExplodePoint;
	float _JunctionSoftness;
	float _OutlineSoftness;
	half _EdgeWidth;
	half3 _EdgeColor;
	half3 _BackgroundColor;

	inline float2 SafeNormalize(float2 inVec)
	{
		real dp2 = max(FLT_MIN, dot(inVec, inVec));
		return inVec * rsqrt(dp2);
	}

	inline float Sqr(float2 val)
	{
		return dot(val, val);
	}

	inline float PDnrand(float2 n)
	{
		return frac(sin(dot(n.xy, float2(12.9898f, 78.233f))) * 43758.5453f);
	}

	float2 Rot(float2 uv, float angle)
	{
		float c, s;
		sincos(angle, c, s);
		float x = c * uv.x - s * uv.y;
		float y = s * uv.x + c * uv.y;

		return float2(x, y);
	}

	float2 Rot(float2 uv, float c, float s)
	{
		float x = c * uv.x - s * uv.y;
		float y = s * uv.x + c * uv.y;

		return float2(x, y);
	}

	inline half4 SampleSrcTex(float2 uv)
	{
		return SAMPLE_TEXTURE2D(_SrcTex, s_linear_clamp_sampler, uv);
	}

	v2f vert(a2v IN)
	{
		v2f o;
		o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
		return o;
	}
	ENDHLSL

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
			Name "BlackWhiteLine Outline"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols

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

			half Outline(float2 uv)
			{
				half outlineFade = Scharr(_EdgeWidth / _ScreenParams.x, _EdgeWidth / _ScreenParams.y, uv);

				return 1 - outlineFade;
			}

			//生成随机noise 储存用
			half Line(float2 uv)
			{
				float ctrl = _ProgressCtrl;
				float2 cellCount = ceil(_CellCount * (1 - ctrl));
				float2 cellPos = uv * cellCount;
				float2 cellUV = frac(cellPos);
				float2 cellIndex = ceil(cellPos);
				float noise = PDnrand(cellUV.xx * cellIndex * _CellFrequent);
				return noise;
			}

			half4 frag(v2f IN) : SV_Target
			{
				half4 col;
				col.r = Outline(IN.uv);
				col.g = Line(IN.uv);
				col.ba = 0;
				return col;
			}
			ENDHLSL
		}

		Pass
		{
			Name "BlackWhiteLine Outline"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols

			void CalcJunction(float2 uv, out float whiteJunction, out float outlineJunction)
			{
				float ctrl = _ProgressCtrl;
				float2 explodePoint = _ExplodePoint;
				// float aspect = _ScreenParams.x / _ScreenParams.y;
				// uv.x *= aspect;
				// explodePoint.x *= aspect;
				float x = (uv.x - explodePoint.x);
				float y = (uv.y - explodePoint.y);
				float d = x * x + y * y;

				//圆太规则了 , 制造出凹凸坑洼的效果
				float sin_theta = y / max(sqrt(d), 1e-8); //d = r^2 同时避免NAN
				float half_theta = asin(sin_theta) * (step(0, x) - 0.5); //根据x进行凹凸
				float ang_theta = max(abs(sin(half_theta * 24)), 0.5);
				float deformFactor = ctrl * 0.1 * ang_theta;

				float maxLen = max(Sqr(1 - _ExplodePoint), Sqr(_ExplodePoint));
				float junctionLen = maxLen * ctrl + deformFactor;
				float nowLen = Sqr(uv - _ExplodePoint);
				whiteJunction = smoothstep(junctionLen, junctionLen + _JunctionSoftness * ctrl, nowLen);
				outlineJunction = smoothstep(junctionLen, junctionLen + _OutlineSoftness * ctrl, nowLen);
			}

			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;
				float2 pixelSize = _ScreenParams.zw - 1;
				float ctrl = _ProgressCtrl;
				float p2Ctrl = max(ctrl - 0.5, 0);

				//原图
				//------------------
				half3 sceneColor = SAMPLE_TEXTURE2D(_SceneTex, s_point_clamp_sampler, uv).rgb;

				//line
				//---------------
				float2 dir = SafeNormalize(0.5 - _ExplodePoint);
				float2 lineUV = Rot(uv - 0.5, dir.y, dir.x) + 0.5;
				half lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).g;
				float2 lineUVOffset = lineNoise.xx * lerp(0.1, 0.8, p2Ctrl) * p2Ctrl + 100 * pixelSize * p2Ctrl;
				half isOutline1 = SampleSrcTex(uv - lineUVOffset).r;

				half isOutline2 = 1;
				if (ctrl > 0.3)
				{
					lineUV = Rot(uv - dir - 0.5, dir.y, dir.x) + 0.5;
					lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).g;
					lineUVOffset = lineNoise.xx * 0.45 * p2Ctrl + 200 * pixelSize * p2Ctrl;
					isOutline2 = 0.2 + SampleSrcTex(uv - lineUVOffset).r;
				}

				half isOutline3 = 1;
				if (ctrl > 0.6)
				{
					lineUV = Rot(uv - 2 * dir - 0.5, dir.y, dir.x) + 0.5;
					lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).g;
					lineUVOffset = lineNoise.xx * 0.8 * p2Ctrl + 150 * pixelSize * p2Ctrl;
					isOutline3 = 0.4 + SampleSrcTex(uv - lineUVOffset).r;
				}


				//交界处
				//-------------------------------
				float whiteJunc, outlineJunc;
				CalcJunction(uv, whiteJunc, outlineJunc);

				half3 col = lerp(_BackgroundColor, sceneColor, whiteJunc);
				float isOutline = min(isOutline1, isOutline2);
				isOutline = min(isOutline, isOutline3);
				if (isOutline < 0.5 && outlineJunc < 0.99)
				{
					half3 edgeColor = lerp(_EdgeColor, _BackgroundColor, smoothstep(0.8, 1, outlineJunc));
					col *= lerp(edgeColor, _BackgroundColor, p2Ctrl * 2);
				}

				return half4(col, 1);
			}
			ENDHLSL
		}

		Pass
		{
			Name "Blit"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols


			half4 frag(v2f IN) : SV_Target
			{
				return SampleSrcTex(IN.uv);
			}
			ENDHLSL
		}
	}
}