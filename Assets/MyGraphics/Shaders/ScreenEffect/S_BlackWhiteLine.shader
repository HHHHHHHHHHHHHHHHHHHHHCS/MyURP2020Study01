Shader "MyRP/ScreenEffect/S_BlackWhiteLine"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl", Range(0, 1)) = 0.5
		//_CellCount("Cell Count", Vector) = (50, 200, 0, 0)
		//_CellFrequent("Cell Frequent",Range(0.01,10)) = 1
		_ExplodePoint("Explode Point", Vector) = (0, 0, 0, 0)
		_JunctionSoftness("Junction Softness",Range(0,2)) = 1
		_OutlineSoftness("Outline Softness",Range(0,4)) = 2
		_LineNoiseTex("Line Noise Texture", 2D) = "black"{}
		[Header(Edge)] _EdgeWidth("Edge Width", Range(0.05,5)) = 0.3
		_EdgeColor("Edge Color", Color) = (0, 0, 0, 1)
		[Header(Background)] _BackgroundColor("Bakcground Color", Color) = (1, 1, 1, 1)

		[Header(Distort)]_ReflectionColor("Reflection Color", Color) = (0.5, 0.5, 0.5, 1)
		_ReflectionRefraction("Reflection Refraction",Float) = 0.5
		_ReflectionIntensity("Reflection Reflection",Float) = 0.25
		_ExplodeIntensity("Explode Intensity",Vector) = (1,1,1,0)
		_ExplodeInterval("Explode Interval",Float) = 0.8

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
	half3 _ReflectionColor;
	float _ReflectionRefraction;
	float3 _ExplodeIntensity;
	float _ExplodeInterval;

	inline float2 SafeNormalize(float2 inVec)
	{
		real dp2 = max(FLT_MIN, dot(inVec, inVec));
		return inVec * rsqrt(dp2);
	}

	inline float Sqr(float2 val)
	{
		return dot(val, val);
	}

	// inline float PDnrand(float2 n)
	// {
	// 	return frac(sin(dot(n.xy, float2(12.9898f, 78.233f))) * 43758.5453f);
	// }

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

			// #pragma enable_d3d11_debug_symbols

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
			// half Line(float2 uv)
			// {
			// 	float ctrl = _ProgressCtrl;
			// 	float2 cellCount = ceil(_CellCount * (1 - ctrl));
			// 	float2 cellPos = uv * cellCount;
			// 	float2 cellUV = frac(cellPos);
			// 	float2 cellIndex = ceil(cellPos);
			// 	float noise = PDnrand(cellUV.xx * cellIndex * _CellFrequent);
			// 	return noise;
			// }


			void CalcJunction(float2 uv, out float whiteJunction, out float outlineJunction)
			{
				float2 explodePoint = _ExplodePoint;
				// float aspect = _ScreenParams.x / _ScreenParams.y;
				// uv.x *= aspect;
				float ctrl = _ProgressCtrl; //* aspect
				// explodePoint.x *= aspect;
				float x = (uv.x - explodePoint.x);
				float y = (uv.y - explodePoint.y);
				float d = x * x + y * y;

				//圆太规则了 , 制造出凹凸坑洼的效果
				float sin_theta = y / max(sqrt(d), 1e-8); //d = r^2 同时避免NAN
				float half_theta = asin(sin_theta) * (step(0, x) - 0.5); //根据x进行凹凸
				float ang_theta = max(abs(sin(half_theta * 24)), 0.5);
				float deformFactor = ctrl * 0.1 * ang_theta;

				float maxLen = max(Sqr(1 - explodePoint), Sqr(explodePoint));
				float junctionLen = maxLen * ctrl + deformFactor;
				float nowLen = Sqr(uv - explodePoint);
				whiteJunction = smoothstep(junctionLen, junctionLen + _JunctionSoftness * ctrl, nowLen);
				outlineJunction = smoothstep(junctionLen, junctionLen + _OutlineSoftness * ctrl, nowLen);
			}


			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;

				//交界处
				//-------------------------------
				float whiteJunc, outlineJunc;
				CalcJunction(uv, whiteJunc, outlineJunc);

				half isOutline = Outline(uv);

				//原图
				//------------------
				half3 sceneColor = SampleSrcTex(uv).rgb;


				half3 col = lerp(_BackgroundColor, sceneColor, whiteJunc);
				if (isOutline < 0.5)
				{
					col = lerp(_EdgeColor, col, smoothstep(0.7, 1, outlineJunc));
				}

				return half4(col, 1);
			}
			ENDHLSL
		}

		Pass
		{
			Name "BlackWhiteLine Outline"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

			float CalcT(float x)
			{
				float t = lerp(30, 1, _ProgressCtrl) * (x - 0.075);
				t = saturate(-(t * t) + 1);
				return smoothstep(0, 1, t);
			}

			float Wave(float2 position, float2 origin, float time)
			{
				float d = length(position - origin);
				float t = time - d * _ExplodeInterval;
				return 2 * CalcT(t) - 1;
			}

			float AllWave(float2 position)
			{
				float t = _ProgressCtrl * lerp(12, .1, _ProgressCtrl) + min(_ProgressCtrl * 100, 0.1);
				float2 xy = _ScreenParams.zw - 1;
				return (2 * Wave(position, _ExplodePoint.xy, t) +
					1 * Wave(position, _ExplodePoint.xy + 40 * float2(0, xy.y), t) +
					1 * Wave(position, _ExplodePoint.xy - 40 * float2(xy.x, 0), t));
			}


			half4 frag(v2f IN) : SV_Target
			{
				float2 uv = IN.uv;
				float2 pixelSize = _ScreenParams.zw - 1;
				float ctrl = _ProgressCtrl;

				//distort
				//---------
				float fr = 0;
				if (ctrl < 0.3)
				{
					const float2 dx = float2(10 * pixelSize.x, 0);
					const float2 dy = float2(0, 10 * pixelSize.y);

					float2 p = IN.uv; //* _ScreenParams.x / _ScreenParams.y;

					float w = AllWave(p);

					float2 dw = float2(AllWave(p + dx) - w, AllWave(p + dy) - w);

					float2 duv = dw * _ExplodeIntensity.xy * 0.2 * _ExplodeIntensity.z;
					uv += duv;
					fr = pow(length(dw) * 3 * _ReflectionRefraction, 3);
				}


				//line
				//---------------
				float p2Ctrl = max(ctrl - 0.5, 0);
				float p3Ctrl = max(ctrl - 0.7, 0.0) * 3.34;
				float2 uv0 = uv - 0.5 + _ExplodePoint;
				float2 uv1 = 0.5 - _ExplodePoint;
				float2 pixelOffset = pixelSize * p2Ctrl;
				float2 dir = SafeNormalize(uv - _ExplodePoint);
				float2 signDir = sign(dir);
				float dist = Sqr(uv - _ExplodePoint);

				float2 intensity = lerp(dist,1,p3Ctrl) * smoothstep( 0,pixelSize*20,abs(uv-_ExplodePoint));

				float2 lineUV = Rot(uv0, dir.y, dir.x) + uv1;
				half lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).r;
				float2 lineUVOffset = lineNoise.xx * lerp(0.1, 0.8, p2Ctrl) * p2Ctrl + 100 * pixelOffset;
				lineUVOffset *= intensity * signDir;
				half3 outline1 = 1000 * p2Ctrl * Sqr(lineUVOffset) * _BackgroundColor + SampleSrcTex(uv - lineUVOffset).
					rgb;

				half3 outline2 = _BackgroundColor;
				half3 outline3 = _BackgroundColor;
				if (ctrl > 0.3)
				{
					lineUV = Rot(uv0 - dir, dir.y, dir.x) + uv1;
					lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).r;
					lineUVOffset = lineNoise.xx * 0.45 * p2Ctrl + 200 * pixelOffset;
					lineUVOffset *= intensity * signDir;
					outline2 = 1250 * p2Ctrl * Sqr(lineUVOffset) * _BackgroundColor + SampleSrcTex(uv - lineUVOffset).
						rgb;

					if (ctrl > 0.6)
					{
						lineUV = Rot(uv0 - 2 * dir, dir.y, dir.x) + uv1;
						lineNoise = SAMPLE_TEXTURE2D(_LineNoiseTex, s_linear_repeat_sampler, lineUV).r;
						lineUVOffset = lineNoise.xx * 0.8 * p2Ctrl + 150 * pixelOffset;
						lineUVOffset *= intensity * signDir;
						outline3 = 1500 * p2Ctrl * Sqr(lineUVOffset) * _BackgroundColor + SampleSrcTex(
							uv - lineUVOffset).rgb;
					}
				}


				half3 outlineCol = min(outline1, outline2);
				outlineCol = min(outlineCol, outline3);

				outlineCol = lerp(outlineCol, _BackgroundColor, saturate(15 * (ctrl - 0.8) - Sqr(uv - _ExplodePoint)));
				outlineCol = lerp(outlineCol, _ReflectionColor, fr);

				return half4(outlineCol, 1);
			}
			ENDHLSL
		}

		Pass
		{
			Name "Blit"

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			// #pragma enable_d3d11_debug_symbols

			half4 frag(v2f IN) : SV_Target
			{
				return SampleSrcTex(IN.uv);
			}
			ENDHLSL
		}
	}
}