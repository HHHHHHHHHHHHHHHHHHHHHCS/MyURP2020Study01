Shader "MyRP/ScreenEffect/S_DissolveOut"
{
	Properties
	{
		_ProgressCtrl("Progress Ctrl",Range(0,1))=0.5
		_DistortCtrl("Distort Ctrl",Range(0.001,3))=0.5
		_OutlineCtrl("Outline Ctrl",Range(0.0,1))=1.0
		[Toggle]_3DUV("_3DUV",Int)=0
		_UVOffset("UV Offset",Vector)=(0.0,0.0,0,0)
		_FrontTex("Front Texture",2D)="white"{}
		_BackTex("Back Texture",2D)="black"{}
		_DistortTex("Distort Texture",2D)="white"{}
		_MaskTex("Mask Texture",2D)="white"{}
		_DissolveTex("Dissolve Texture",2D)="white"{}
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Dissolve Out"
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
			TEXTURE2D_X(_DistortTex);
			TEXTURE2D_X(_MaskTex);
			TEXTURE2D_X(_DissolveTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(s_linear_clamp_sampler);
			SAMPLER(s_linear_repeat_sampler);

			float _ProgressCtrl;
			float _DistortCtrl;
			float _OutlineCtrl;
			float2 _UVOffset;

			float Remap(float x, float t1, float t2, float s1, float s2)
			{
				return (x - t1) / (t2 - t1) * (s2 - s1) + s1;
			}

			// #if _3DUV_ON

			// old code
			// float2 Use3DUV(float2 inUV, float2 uvOffset)
			// {
			// 	float2 uv = inUV - uvOffset;
			//
			// 	float depth = saturate(1 - length(uv - 0.5) * 0.707107);
			//
			// 	uv = uv * 2 - 1;
			//
			// 	float4x4 invVP = UNITY_MATRIX_I_VP;
			//
			// 	float4 worldPos = mul(invVP, float4(uv, 0, 1));
			// 	worldPos.xyzw /= worldPos.w;
			// 	worldPos.xyz += GetCameraPositionWS() * (0.5 * depth * _ProjectionParams.z);
			// 	float4 hclipPos = mul(UNITY_MATRIX_VP, worldPos);
			// 	hclipPos.xyzw /= hclipPos.w;
			// 	float2 newUV = hclipPos.xy * 0.5 + 0.5;
			// 	return lerp(0, 0.5, 0.5 - abs(_ProgressCtrl - 0.5)) * (inUV - newUV + uvOffset);
			// }

			float2 Use3DUV(float2 inUV, float2 uvOffset, float ctrl)
			{
				float2 uv = inUV - 0.5 - uvOffset;
				float t = abs(dot(uv, uvOffset));
				t *= lerp(0, 2, ctrl);
				float len = max(0.001, length(uvOffset));
				return t * uvOffset / len;
			}

			float2 RotFrontUV(float2 inUV, float2 uvOffset, float ctrl)
			{
				const float range = 0.5;
				const float angle = -PI/6;
				
				uvOffset += 0.5;
				float d = distance(inUV, uvOffset);
				inUV -= uvOffset;
				// d = clamp(-angle/range * d + angle,0.,angle); // 线性方程
				d = smoothstep(0., range, range - d) * angle * 50 * ctrl;
				float s, c;
				sincos(d, s, c);
				float2 temp = mul(float2x2(c, -s, s, c), inUV);
				temp += uvOffset;
				return temp;
			}

			// #endif

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
				float2 uvOffset = uv - _UVOffset;
				#if _3DUV_ON
				uvOffset += Use3DUV(uv, _UVOffset,ctrl);
				#endif
				float distortCtrl = ctrl * 3 + 0.001; //_DistortCtrl


				//Distort
				//-----------
				float2 distortUV = (uvOffset - 0.5) / distortCtrl + 0.5;
				half2 distortCol = SAMPLE_TEXTURE2D(_DistortTex, s_linear_clamp_sampler, distortUV).rg;
				distortUV = (distortCol - 0.5) * ctrl * 0.04;


				//mask
				//-----------
				float maskA = clamp(ctrl * 4 - 1, 0, 10);
				float maskB = ctrl * 0.5 + 1;
				float maskC = step(0, maskA - maskB);
				float maskScale = lerp(maskA, maskB, maskC);

				float2 maskUV = (uvOffset - 0.5) / maskScale + 0.5;
				half mask = SAMPLE_TEXTURE2D(_MaskTex, s_linear_clamp_sampler, distortUV + maskUV).r;

				//dissolve
				//-----------
				float dissolveA = clamp(ctrl * 3 - 0.4, 0, 10);
				float dissolveB = ctrl * 0.4 + 1;
				float dissolveC = step(0.0, dissolveA - dissolveB);
				float dissolveScale = lerp(dissolveA, dissolveB, dissolveC);

				float2 dissolveUV = (uvOffset - 0.5) / dissolveScale + 0.5;
				half dissolve = SAMPLE_TEXTURE2D(_DissolveTex, s_linear_clamp_sampler, distortUV + dissolveUV).r;

				//backTex
				//-----------
				float backScale = (ctrl * 2 - 1) * 0.4 + 0.6;
				float2 backUV = (uv - 0.5 - _UVOffset) / backScale + 0.5 + _UVOffset;
				half3 backCol = SAMPLE_TEXTURE2D(_BackTex, s_linear_clamp_sampler, backUV).rgb;

				//frontTex
				//-----------
				float frontScale = smoothstep(0, 1, ctrl) + 1;
				float2 frontUV = RotFrontUV(uv, _UVOffset, ctrl);
				frontUV = (frontUV - float2(0.5, 0.3) - _UVOffset) / frontScale + float2(0.5, 0.3) + _UVOffset;
				half3 frontCol = SAMPLE_TEXTURE2D(_FrontTex, s_linear_clamp_sampler, frontUV).rgb;

				float remapCtrl = Remap(ctrl, 0, 1, -0.7, 1) + dissolve;
				float tempCtrl = (2 - ctrl) * mask * 5 + remapCtrl;

				//purple
				//-----------
				const float purpleA = 0.2;
				const float purpleB = 0.3;
				float purpleStrength = smoothstep(purpleA, purpleB, tempCtrl) * smoothstep(purpleB, purpleA, tempCtrl);
				purpleStrength = pow(purpleStrength, 0.5);
				half3 purple = half3(0.08228, 0, 1) * purpleStrength;

				//white
				//-----------
				const float whiteA = 0.5;
				const float whiteB = 0.55;
				float whiteStrength = smoothstep(whiteA, whiteB, tempCtrl) * smoothstep(whiteB, whiteA, tempCtrl);
				whiteStrength = pow(whiteStrength, 0.5);
				half3 white = half3(1, 1, 1) * whiteStrength;


				frontCol += (purple + white) * _OutlineCtrl;

				float lerpAlpha = smoothstep(0.77, 0.75, remapCtrl);

				half3 finalCol = lerp(backCol, frontCol, lerpAlpha);

				return half4(finalCol, 1);
			}
			ENDHLSL
		}
	}
}