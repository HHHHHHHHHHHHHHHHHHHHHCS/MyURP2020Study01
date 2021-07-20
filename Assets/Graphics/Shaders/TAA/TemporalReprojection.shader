Shader "MyRP/TAA/TemporalReprojection"
{
	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	struct a2v
	{
		uint vertexID : SV_VertexID;
	};

	struct v2f
	{
		float4 pos: SV_POSITION;
		float2 uv: TEXCOORD0;
	};

	v2f vert(a2v v)
	{
		v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
		o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
		return o;
	}
	ENDHLSL

	SubShader
	{
		ZTest LEqual Cull Back ZWrite On
		Fog
		{
			Mode Off
		}

		//0:TAA
		Pass
		{
			// #pragma enable_d3d11_debug_symbols

			Name "TAA"
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment taa_frag
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			#pragma multi_compile MINMAX_3X3 MINMAX_3X3_ROUNDED MINMAX_4TAP_VARYING
			#pragma multi_compile _ UNJITTER_COLORSAMPLES
			#pragma multi_compile _ UNJITTER_NEIGHBORHOOD
			#pragma multi_compile _ UNJITTER_REPROJECTION
			#pragma multi_compile _ USE_YCOCG
			#pragma multi_compile _ USE_CLIPPING
			#pragma multi_compile _ USE_DILATION
			#pragma multi_compile _ USE_MOTION_BLUR
			#pragma multi_compile _ USE_MOTION_BLUR_NEIGHBORMAX
			#pragma multi_compile _ USE_OPTIMIZATIONS

			float4 _CameraDepthTexture_TexelSize;

			TEXTURE2D(_SrcTex);
			float4 _SrcTex_TexelSize;
			SAMPLER(sampler_SrcTex);

			TEXTURE2D(_PrevTex);
			SAMPLER(sampler_PrevTex);

			TEXTURE2D(_VelocityBufferTex);
			SAMPLER(sampler_VelocityBufferTex);

			TEXTURE2D(_VelocityNeighborMax);
			SAMPLER(sampler_VelocityNeighborMax);

			float4 _Corner; // xy = ray to (1,1) corner of unjittered frustum at distance 1
			float4 _Jitter; // xy = current frame, zw = previous
			float4x4 _PrevVP;
			float _FeedbackMin;
			float _FeedbackMax;
			float _MotionScale;


			//noise---------------------------

			//note: normalized random, float=[0;1[
			float PDnrand(float2 n)
			{
				return frac(sin(dot(n.xy, float2(12.9898f, 78.233f))) * 43758.5453f);
			}

			float2 PDnrand2(float2 n)
			{
				return frac(sin(dot(n.xy, float2(12.9898f, 78.233f))) * float2(43758.5453f, 28001.8384f));
			}

			float3 PDnrand3(float2 n)
			{
				return frac(sin(dot(n.xy, float2(12.9898f, 78.233f))) * float3(43758.5453f, 28001.8384f, 50849.4141f));
			}

			float4 PDnrand4(float2 n)
			{
				return frac(
					sin(dot(n.xy, float2(12.9898f, 78.233f))) *
					float4(43758.5453f, 28001.8384f, 50849.4141f, 12996.89f));
			}

			//====
			//note: signed random, float=[-1;1[
			float PDsrand(float2 n)
			{
				return PDnrand(n) * 2 - 1;
			}

			float2 PDsrand2(float2 n)
			{
				return PDnrand2(n) * 2 - 1;
			}

			float3 PDsrand3(float2 n)
			{
				return PDnrand3(n) * 2 - 1;
			}

			float4 PDsrand4(float2 n)
			{
				return PDnrand4(n) * 2 - 1;
			}

			//function-----------------------------

			// https://software.intel.com/en-us/node/503873
			half3 RGB_YCoCg(float3 c)
			{
				// Y = R/4 + G/2 + B/4
				// Co = R/2 - B/2
				// Cg = -R/4 + G/2 - B/4
				return float3(
					c.x / 4.0 + c.y / 2.0 + c.z / 4.0,
					c.x / 2.0 - c.z / 2.0,
					-c.x / 4.0 + c.y / 2.0 - c.z / 4.0
				);
			}

			// https://software.intel.com/en-us/node/503873
			half3 YCoCg_RGB(float3 c)
			{
				// R = Y + Co - Cg
				// G = Y + Cg
				// B = Y - Co - Cg
				return saturate(float3(
					c.x + c.y - c.z,
					c.x + c.z,
					c.x - c.y - c.z
				));
			}

			half4 SampleColor(TEXTURE2D_PARAM(tex, samp), float2 uv)
			{
				#if USE_YCOCG
				half4 c = SAMPLE_TEXTURE2D(tex, samp, uv);
				return half4(RGB_YCoCg(c.rgb), c.a);
				#else
				return SAMPLE_TEXTURE2D(tex, samp, uv);
				#endif
			}

			float4 ResolveColor(float4 c)
			{
				#if USE_YCOCG
				return float4(YCoCg_RGB(c.rgb).rgb, c.a);
				#else
				return c;
				#endif
			}

			half4 ClipAABB(half3 aabb_min, half3 aabb_max, float4 p, float4 q)
			{
				#if USE_OPTIMIZATIONS
				// note: only clips towards aabb center (but fast!)
				float3 p_clip = 0.5 * (aabb_max + aabb_min);
				float3 e_clip = 0.5 * (aabb_max - aabb_min);

				float4 v_clip = q - float4(p_clip, p.w);
				float3 v_unit = v_clip.xyz / e_clip;
				float3 a_unit = abs(v_unit);
				float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

				if (ma_unit > 1.0)
					return float4(p_clip, p.w) + v_clip / ma_unit;
				else
					return q; // point inside aabb
				#else
				float4 r = q - p;
				float3 rmax = aabb_max - p.xyz;
				float3 rmin = aabb_min - p.xyz;

				const float eps = FLT_EPS;

				if (r.x > rmax.x + eps)
					r *= (rmax.x / r.x);
				if (r.y > rmax.y + eps)
					r *= (rmax.y / r.y);
				if (r.z > rmax.z + eps)
					r *= (rmax.z / r.z);

				if (r.x < rmin.x - eps)
					r *= (rmin.x / r.x);
				if (r.y < rmin.y - eps)
					r *= (rmin.y / r.y);
				if (r.z < rmin.z - eps)
					r *= (rmin.z / r.z);

				return p + r;
				#endif
			}

			float3 FindClosestFragment(float2 uv)
			{
				float2 dd = _CameraDepthTexture_TexelSize.xy;
				float2 du = float2(dd.x, 0.0);
				float2 dv = float2(0.0, dd.y);

				float3 dtl = float3(-1, -1, SampleSceneDepth(uv - dv - du));
				float3 dtc = float3(0, -1, SampleSceneDepth(uv - dv));
				float3 dtr = float3(1, -1, SampleSceneDepth(uv - dv + du));

				float3 dml = float3(-1, 0, SampleSceneDepth(uv - du));
				float3 dmc = float3(0, 0, SampleSceneDepth(uv));
				float3 dmr = float3(1, 0, SampleSceneDepth(uv + du));

				float3 dbl = float3(-1, 1, SampleSceneDepth(uv + dv - du));
				float3 dbc = float3(0, 1, SampleSceneDepth(uv + dv));
				float3 dbr = float3(1, 1, SampleSceneDepth(uv + dv + du));

				float3 dmin = dtl;
				if (dmin.z > dtc.z) dmin = dtc;
				if (dmin.z > dtr.z) dmin = dtr;

				if (dmin.z > dml.z) dmin = dml;
				if (dmin.z > dmc.z) dmin = dmc;
				if (dmin.z > dmr.z) dmin = dmr;

				if (dmin.z > dbl.z) dmin = dbl;
				if (dmin.z > dbc.z) dmin = dbc;
				if (dmin.z > dbr.z) dmin = dbr;

				return float3(uv + dd.xy * dmin.xy, dmin.z);
			}

			half4 SampleColorMotion(TEXTURE2D_PARAM(tex, samp), float2 uv, float2 ss_vel)
			{
				const float2 v = 0.5 * ss_vel;
				const int taps = 3; // on either side!

				float srand = PDsrand(uv + _SinTime.xx);
				float2 vtap = v / taps;
				float2 pos0 = uv + vtap * (0.5 * srand);
				half4 accu = 0.0;
				float wsum = 0.0;

				for (int i = -taps; i <= taps; i++)
				{
					float w = 1.0f; // box
					//float w = taps - abs(i) + 1;// triangle
					//float w = 1.0 / (1 + abs(i));// pointy triangle
					accu += w * SampleColor(tex, samp, pos0 + i * vtap);
					wsum += w;
				}

				return accu / wsum;
			}

			half4 TemporalReprojection(float2 ss_txc, float2 ss_vel, float vs_dist)
			{
				#if UNJITTER_COLORSAMPLES || UNJITTER_NEIGHBORHOOD
				float2 jitter0 = _Jitter.xy * _SrcTex_TexelSize.xy;
				#endif

				// read texels
				#if UNJITTER_COLORSAMPLES
				half4 texel0 = SampleColor(_SrcTex, sampler_SrcTex, ss_txc - jitter0);
				#else
				half4 texel0 = SampleColor(_SrcTex, sampler_SrcTex, ss_txc);
				#endif

				half4 texel1 = SampleColor(_PrevTex, sampler_PrevTex, ss_txc - ss_vel);

				#if UNJITTER_NEIGHBORHOOD
				float2 uv = ss_txc - jitter0;
				#else
				float2 uv = ss_txc;
				#endif

				#if MINMAX_3X3 || MINMAX_3X3_ROUNDED

				float2 du = float2(_SrcTex_TexelSize.x, 0.0);
				float2 dv = float2(0.0, _SrcTex_TexelSize.y);

				half4 ctl = SampleColor(_SrcTex, sampler_SrcTex, uv - dv - du);
				half4 ctc = SampleColor(_SrcTex, sampler_SrcTex, uv - dv);
				half4 ctr = SampleColor(_SrcTex, sampler_SrcTex, uv - dv + du);
				half4 cml = SampleColor(_SrcTex, sampler_SrcTex, uv - du);
				half4 cmc = SampleColor(_SrcTex, sampler_SrcTex, uv);
				half4 cmr = SampleColor(_SrcTex, sampler_SrcTex, uv + du);
				half4 cbl = SampleColor(_SrcTex, sampler_SrcTex, uv + dv - du);
				half4 cbc = SampleColor(_SrcTex, sampler_SrcTex, uv + dv);
				half4 cbr = SampleColor(_SrcTex, sampler_SrcTex, uv + dv + du);

				half4 cmin = min(ctl, min(ctc, min(ctr, min(cml, min(cmc, min(cmr, min(cbl, min(cbc, cbr))))))));
				half4 cmax = max(ctl, max(ctc, max(ctr, max(cml, max(cmc, max(cmr, max(cbl, max(cbc, cbr))))))));

				#if MINMAX_3X3_ROUNDED || USE_YCOCG || USE_CLIPPING
				half4 cavg = (ctl + ctc + ctr + cml + cmc + cmr + cbl + cbc + cbr) / 9.0;
				#endif

				#if MINMAX_3X3_ROUNDED
					half4 cmin5 = min(ctc, min(cml, min(cmc, min(cmr, cbc))));
					half4 cmax5 = max(ctc, max(cml, max(cmc, max(cmr, cbc))));
					half4 cavg5 = (ctc + cml + cmc + cmr + cbc) / 5.0;
					cmin = 0.5 * (cmin + cmin5);
					cmax = 0.5 * (cmax + cmax5);
					cavg = 0.5 * (cavg + cavg5);
				#endif

				#elif MINMAX_4TAP_VARYING// this is the method used in v2 (PDTemporalReprojection2)

				const float _SubpixelThreshold = 0.5;
				const float _GatherBase = 0.5;
				const float _GatherSubpixelMotion = 0.1666;

				float2 size = _SrcTex_TexelSize.xy;
				float2 texel_vel = ss_vel / size.xy;
				float texel_vel_mag = length(texel_vel) * vs_dist;
				float k_subpixel_motion = saturate(_SubpixelThreshold / (FLT_EPS + texel_vel_mag));
				float k_min_max_support = _GatherBase + _GatherSubpixelMotion * k_subpixel_motion;

				float2 ss_offset01 = k_min_max_support * float2(-size.x, size.y);
				float2 ss_offset11 = k_min_max_support * float2(size.x, size.y);
				half4 c00 = SampleColor(_SrcTex, sampler_SrcTex, uv - ss_offset11);
				half4 c10 = SampleColor(_SrcTex, sampler_SrcTex, uv - ss_offset01);
				half4 c01 = SampleColor(_SrcTex, sampler_SrcTex, uv + ss_offset01);
				half4 c11 = SampleColor(_SrcTex, sampler_SrcTex, uv + ss_offset11);

				half4 cmin = min(c00, min(c10, min(c01, c11)));
				half4 cmax = max(c00, max(c10, max(c01, c11)));

				#if USE_YCOCG || USE_CLIPPING
					half4 cavg = (c00 + c10 + c01 + c11) / 4.0;
				#endif

				#else// fallback (... should never end up here)

				half4 cmin = texel0;
				half4 cmax = texel0;

				#if USE_YCOCG || USE_CLIPPING
					half4 cavg = texel0;
				#endif

				#endif


				// shrink chroma min-max
				#if USE_YCOCG
				half2 chroma_extent = 0.25 * 0.5 * (cmax.r - cmin.r);
				half2 chroma_center = texel0.gb;
				cmin.yz = chroma_center - chroma_extent;
				cmax.yz = chroma_center + chroma_extent;
				cavg.yz = chroma_center;
				#endif

				// clamp to neighbourhood of current sample
				#if USE_CLIPPING
				texel1 = ClipAABB(cmin.rgb, cmax.rgb, clamp(cavg, cmin, cmax), texel1);
				#else
				texel1 = clamp(texel1, cmin, cmax);
				#endif

				// feedback weight from unbiased luminance diff (t.lottes)
				#if USE_YCOCG
				float lum0 = texel0.r;
				float lum1 = texel1.r;
				#else
				float lum0 = Luminance(texel0.rgb);
				float lum1 = Luminance(texel1.rgb);
				#endif
				float unbiased_diff = abs(lum0 - lum1) / max(lum0, max(lum1, 0.2));
				float unbiased_weight = 1.0 - unbiased_diff;
				float unbiased_weight_sqr = unbiased_weight * unbiased_weight;
				float k_feedback = lerp(_FeedbackMin, _FeedbackMax, unbiased_weight_sqr);

				// output
				return lerp(texel0, texel1, k_feedback);
			}


			half4 taa_frag(v2f IN):SV_Target
			{
				half4 OUT;

				#if UNJITTER_REPROJECTION || (USE_MOTION_BLUR && UNJITTER_COLORSAMPLES)
				float2 jitter0 = _Jitter.xy * _SrcTex_TexelSize.xy;
				#endif

				float2 uv = IN.uv;
				#if UNJITTER_REPROJECTION
				uv -= jitter0;
				#endif

				#if USE_DILATION
				////--- 3x3 norm (sucks)
				//float2 ss_vel = sample_velocity_dilated(_VelocityBufferTex, uv, 1);
				//float vs_dist = LinearEyeDepth(tex2D(_CameraDepthTexture, uv).x);

				////--- 5 tap nearest (decent)
				//float2 du = float2(_MainTex_TexelSize.x, 0.0);
				//float2 dv = float2(0.0, _MainTex_TexelSize.y);

				//float2 tl = 1.0 * (-dv - du );
				//float2 tr = 1.0 * (-dv + du );
				//float2 bl = 1.0 * ( dv - du );
				//float2 br = 1.0 * ( dv + du );

				//float dtl = tex2D(_CameraDepthTexture, uv + tl).x;
				//float dtr = tex2D(_CameraDepthTexture, uv + tr).x;
				//float dmc = tex2D(_CameraDepthTexture, uv).x;
				//float dbl = tex2D(_CameraDepthTexture, uv + bl).x;
				//float dbr = tex2D(_CameraDepthTexture, uv + br).x;

				//float dmin = dmc;
				//float2 dif = 0.0;

				//if (dtl < dmin) { dmin = dtl; dif = tl; }
				//if (dtr < dmin) { dmin = dtr; dif = tr; }
				//if (dbl < dmin) { dmin = dbl; dif = bl; }
				//if (dbr < dmin) { dmin = dbr; dif = br; }

				//float2 ss_vel = tex2D(_VelocityBufferTex, uv + dif).xy;
				//float vs_dist = LinearEyeDepth(dmin);

				//--- 3x3 nearest (good)
				float3 c_frag = FindClosestFragment(uv);
				float2 ss_vel = SAMPLE_TEXTURE2D(_VelocityBufferTex, sampler_VelocityBufferTex, c_frag.xy).xy;
				float vs_dist = LinearEyeDepth(c_frag.z, _ZBufferParams);
				#else
				float2 ss_vel = SAMPLE_TEXTURE2D(_VelocityBufferTex, sampler_VelocityBufferTex, uv).xy;
				float vs_dist = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
				#endif

				// temporal resolve
				half4 colorTemporal = TemporalReprojection(IN.uv, ss_vel, vs_dist);

				#if USE_MOTION_BLUR
				#if USE_MOTION_BLUR_NEIGHBORMAX
				ss_vel = _MotionScale * SAMPLE_TEXTURE2D(_VelocityNeighborMax, sampler_VelocityNeighborMax, IN.uv).xy;
				#else
				ss_vel = _MotionScale * ss_vel;
				#endif

				float vel_mag = length(ss_vel / _SrcTex_TexelSize.xy);
				const float vel_trust_full = 2.0;
				const float vel_trust_none = 15.0;
				const float vel_trust_span = vel_trust_none - vel_trust_full;
				float trust = 1.0 - clamp(vel_mag - vel_trust_full, 0.0, vel_trust_span) / vel_trust_span;

				#if UNJITTER_COLORSAMPLES
				half4 color_motion = SampleColorMotion(_SrcTex, sampler_SrcTex, IN.uv - jitter0, ss_vel);
				#else
						half4 color_motion = SampleColorMotion(_SrcTex, sampler_SrcTex, IN.uv, ss_vel);
				#endif

				half4 to_screen = ResolveColor(lerp(color_motion, colorTemporal, trust));
				#else
				half4 to_screen = ResolveColor(colorTemporal);
				#endif

				//// NOTE: velocity debug
				//to_screen.g += 100.0 * length(ss_vel);
				//to_screen = float4(100.0 * abs(ss_vel), 0.0, 0.0);

				// add noise
				float4 noise4 = PDsrand4(IN.uv + _SinTime.x + 0.6959174) / 510.0;
				OUT = saturate(to_screen + noise4);

				// done
				return OUT;
			}
			ENDHLSL
		}

		//1:Blit
		Pass
		{
			Name "Blit"
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment blit_frag

			TEXTURE2D(_SrcTex);
			SAMPLER(sampler_SrcTex);

			half4 blit_frag(v2f IN):SV_Target
			{
				return SAMPLE_TEXTURE2D(_SrcTex, sampler_SrcTex, IN.uv);
			}
			ENDHLSL
		}

	}
}