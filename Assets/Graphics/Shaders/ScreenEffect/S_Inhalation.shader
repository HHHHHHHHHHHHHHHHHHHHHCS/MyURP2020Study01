Shader "MyRP/ScreenEffect/S_Inhalation"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl",Range(0,1))=0.5
		[Toggle]_3DUV("_3DUV",Int)=0
		_UVOffset("UV Offset",Vector)=(0.0,0.0,0,0) //uv偏移 -0.5~0.
		_TwirlStrength("Twirl Strength",float)=10
		_PlayerPos("Player Pos",Vector)=(0.5,0.0,0,0) //角色位置 0~1
		_FrontTex("Front Texture",2D)="white"{}
		_BackTex("Back Texture",2D)="black"{}
		_DistortUVTex("Distort UV Texture",2D)="black"{}
		_DistortUVStart("Distort UV Start",Range(0,1))=0.2
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Inhalation"
			ZTest Always
			ZWrite Off
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile_local_fragment _ _3DUV_ON

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

			TEXTURE2D_X(_FrontTex);
			TEXTURE2D_X(_BackTex);
			TEXTURE2D_X(_DistortUVTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _ProgressCtrl;
			float4 _UVOffset;
			float _TwirlStrength;
			float _DistortUVStart;

			// #if _3DUV_ON
			float2 _PlayerPos;
			// #endif

			float Remap(float x, float t1, float t2, float s1, float s2)
			{
				return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
			}

			float2 SafeNormalize(float2 inVec)
			{
				float dp2 = max(FLT_MIN, dot(inVec, inVec));
				return inVec * rsqrt(dp2);
			}

			float Length2(float2 v)
			{
				return dot(v, v);
			}

			// #if _3DUV_ON

			float Use3DOffset(float2 uvOffset)
			{
				float2 dir = _UVOffset.xy - _PlayerPos;
				// float s, c;
				// sincos(PI / 2, s, c);
				// dir = float2(c * dir.x - s * dir.y, s * dir.x + c * dir.y);
				dir = SafeNormalize(dir);
				float d = dot(uvOffset, dir);
				return d;
			}


			// #endif

			float2 ScaleUV(float2 uv, float2 center, float ctrl)
			{
				ctrl = smoothstep(0, 1, ctrl);
				// float2 d = normalize(uv - center);
				// center += d * 0.1; // * ctrl;
				float2 dir = (0.5 * ctrl + 0.5) * SafeNormalize(uv - center);
				float2 delta = ctrl * dir;
				uv = uv + delta;
				return uv;
			}

			float2 Twirl(float2 uv, float2 center, float2 offset, float strength)
			{
				float2 delta = uv - center;
				float angle = strength * (1.5 - length(delta));
				float s, c;
				sincos(angle, s, c);
				float x = c * delta.x - s * delta.y;
				float y = s * delta.x + c * delta.y;
				float2 ddd = float2(x, y);
				return float2(x + center.x + offset.x, y + center.y + offset.y);
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
				float ctrl = _ProgressCtrl;
				float2 uv = IN.uv;
				float4 uvOffset = _UVOffset;


				float2 offsetUV = uv - _UVOffset.xy;

				float uv3d = 0;
				// #if _3DUV_ON
				uv3d = Use3DOffset(offsetUV);
				// #endif


				float d0 = 2 * Length2(uvOffset.xy - 0.5);
				d0 = 0.6 * lerp(1, 5, d0) * (1 - ctrl);

				uv3d = ctrl * (1 - 2 * max(ctrl - 0.5, 0.0)) * max(abs(uv3d), 0.01);
				float scaleStr = saturate(ctrl - d0 + uv3d);

				float d = Length2(offsetUV);
				d = Remap(d, 0, 0.75, 0, 1);
				d = pow(d * 0.3, 2 / 3.0);

				float twirlStr = _TwirlStrength * saturate(ctrl - d);

				float2 twirl = ScaleUV(uv, _UVOffset.xy, scaleStr);
				twirl = Twirl(twirl, _UVOffset.xy, _UVOffset.zw, _TwirlStrength * twirlStr);


				float2 nearPoint = clamp(twirl, 0, 1);
				float len = distance(twirl, nearPoint);

				float lerpBack = smoothstep(0.01, 0.2, len);

				float alpha = max(ctrl - 0.95, 0.0) * 20;
				lerpBack = min(lerpBack + alpha, 1.0);

				//backTex
				//-----------
				half3 backCol = SAMPLE_TEXTURE2D(_BackTex, s_linear_clamp_sampler, twirl).rgb;
				float backLine = 2 * twirlStr * ctrl
					* (SAMPLE_TEXTURE2D(_DistortUVTex, s_linear_clamp_sampler, twirl).r);
				backCol += backLine;

				//frontTex
				//-----------
				half3 frontCol = SAMPLE_TEXTURE2D(_FrontTex, s_linear_clamp_sampler, uv).rgb;


				half3 finalCol = lerp(backCol, frontCol, lerpBack);

				return half4(finalCol, 1);
			}
			ENDHLSL
		}
	}
}