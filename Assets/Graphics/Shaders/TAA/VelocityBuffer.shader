Shader "MyRP/TAA/VelocityBuffer"
{
	HLSLINCLUDE
	#pragma enable_d3d11_debug_symbols
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

	TEXTURE2D(_VelocityTex);
	SAMPLER(sampler_Linear_Clamp);
	float4 _VelocityTex_TexelSize;

	int _TileMaxLoop;

	float4 _Corner; // xy = ray to (1,1) corner of unjittered frustum at distance 1, zw = jitter at distance 1

	float4x4 _CurrV;
	float4x4 _CurrVP;
	float4x4 _CurrM;

	float4x4 _PrevVP;
	float4x4 _PrevM;

	//blit-------------------------

	struct blit_a2v
	{
		uint vertexID : SV_VertexID;
	};

	struct blit_v2f
	{
		float4 pos: SV_POSITION;
		float2 uv: TEXCOORD0;
		float2 ray :TEXCOORD1;
	};


	blit_v2f blit_vert(blit_a2v v)
	{
		blit_v2f o;
		o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
		// o.pos.zw = 1;//设置 覆盖 清理Z
		o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
		o.ray = (2.0 * o.uv.xy - 1.0) * _Corner.xy + _Corner.zw;
		return o;
	}

	half4 blit_frag_prepare(blit_v2f IN):SV_Target
	{
		float view_dist = LinearEyeDepth(SampleSceneDepth(IN.uv), _ZBufferParams);
		float3 view_pos = float3(IN.ray, 1.0) * view_dist;
		float4 world_pos = mul(unity_CameraToWorld, float4(view_pos, 1.0));
		
		float4 prev_cs_pos = mul(_PrevVP, world_pos);
		float2 prev_ss_ndc = prev_cs_pos.xy / prev_cs_pos.w;
		float2 prev_ss_uv = 0.5 * prev_ss_ndc + 0.5;

		float2 ss_vel = IN.uv - prev_ss_uv;

		return float4(ss_vel, 0, 0);
	}

	half4 blit_frag_tilemax(blit_v2f IN):SV_Target
	{
		const int support = 1; //_TileMaxLoop;
		const float2 step = _VelocityTex_TexelSize.xy;
		const float2 base = IN.uv + (0.5 - 0.5 * support) * step;
		const float2 du = float2(step.x, 0);
		const float2 dv = float2(0, step.y);

		float2 mv = 0.0;
		float rmv = 0.0;

		for (int i = 0; i < support; i++)
		{
			for (int j = 0; j < support; j++)
			{
				float2 v = SAMPLE_TEXTURE2D(_VelocityTex, sampler_Linear_Clamp, base + i*dv+j*du);
				float rv = dot(v, v);
				if (rv > rmv)
				{
					mv = v;
					rmv = rv;
				}
			}
		}

		return float4(mv, 0.0, 0.0);
	}

	float4 blit_frag_neighbormax(blit_v2f IN):SV_Target
	{
		const float2 du = float2(_VelocityTex_TexelSize.x, 0);
		const float2 dv = float2(0, _VelocityTex_TexelSize.y);

		float2 mv = 0.0;
		float dmv = 0.0;
		for (int i = -1; i <= 1; i++)
		{
			for (int j = -1; j <= 1; j++)
			{
				float2 v = SAMPLE_TEXTURE2D(_VelocityTex, sampler_Linear_Clamp, IN.uv + i*dv + j*du).xy;
				float dv = dot(v, v);
				if (dv > dmv)
				{
					mv = v;
					dmv = dv;
				}
			}
		}

		return float4(mv, 0, 0);
	}

	//obj-------------------------

	struct obj_a2v
	{
		float4 vertex:POSITION;
		float4 prev_vertex:TEXCOORD4;
	};

	struct obj_v2f
	{
		float4 clipPos : SV_POSITION;
		float4 screenPos : TEXCOORD0;
		float3 currClipPos : TEXCOORD1;
		float3 prevClipPos : TEXCOORD2;
	};

	obj_v2f process_vertex(float4 curr_vert, float4 prev_vert)
	{
		obj_v2f o;

		o.clipPos = mul(mul(_CurrVP, _CurrM), curr_vert) * float4(1.0, -1.0, 1.0, 1.0);
		o.screenPos = ComputeScreenPos(o.clipPos);
		o.screenPos.z = -mul(mul(_CurrV, _CurrM), curr_vert).z;
		o.currClipPos = o.clipPos.xyw;
		o.prevClipPos = mul(mul(_PrevVP, _PrevM), prev_vert).xyw * float3(1.0, -1.0, 1.0);


		#if UNITY_UV_STARTS_AT_TOP
		o.currClipPos.y = 1.0 - o.currClipPos.y;
		o.prevClipPos.y = 1.0 - o.prevClipPos.y;
		#endif

		return o;
	}

	obj_v2f obj_vert_mesh(obj_a2v IN)
	{
		return process_vertex(IN.vertex, IN.vertex);
	}

	obj_v2f obj_vert_skinned(obj_a2v IN)
	{
		// previous frame positions stored in normal data
		return process_vertex(IN.vertex, float4(IN.prev_vertex.xyz, 1.0));
	}

	half4 obj_frag(obj_v2f IN) : SV_Target
	{
		float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
		float scene_dist = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);

		const float occlusion_bias = 0.03;
		// discard if occluded
		clip(scene_dist - IN.screenPos.z + occlusion_bias);

		// compute velocity in ndc
		float2 ndc_curr = IN.currClipPos.xy / IN.currClipPos.z;
		float2 ndc_prev = IN.prevClipPos.xy / IN.prevClipPos.z;

		// output screen space velocity [0,1;0,1]
		return float4(0.5 * (ndc_curr - ndc_prev), 0.0, 0.0);
	}
	ENDHLSL

	SubShader
	{
		// 0: prepass
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog
			{
				Mode Off
			}
			Name "prepare"
			HLSLPROGRAM
			#pragma vertex blit_vert
			#pragma fragment blit_frag_prepare
			ENDHLSL
		}

		// 1: vertices
		Pass
		{
			ZTest LEqual Cull Back ZWrite On
			Fog
			{
				Mode Off
			}
			Name "vertices mesh"
			HLSLPROGRAM
			#pragma vertex obj_vert_mesh
			#pragma fragment obj_frag
			ENDHLSL
		}

		// 2: vertices skinned
		Pass
		{
			ZTest LEqual Cull Back ZWrite On
			Fog
			{
				Mode Off
			}
			Name "vertices skinned mesh"
			HLSLPROGRAM
			#pragma vertex obj_vert_skinned
			#pragma fragment obj_frag
			ENDHLSL
		}

		// 3: tilemax
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog
			{
				Mode Off
			}

			Name "tilemax"
			HLSLPROGRAM
			#pragma vertex blit_vert
			#pragma fragment blit_frag_tilemax
			ENDHLSL
		}

		// 4: neighbormax
		Pass
		{
			ZTest Always Cull Off ZWrite Off
			Fog
			{
				Mode Off
			}

			Name "neighbormax"
			HLSLPROGRAM
			#pragma vertex blit_vert
			#pragma fragment blit_frag_neighbormax
			ENDHLSL
		}
	}
}