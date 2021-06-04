Shader "MyRP/ScreenEffect/S_FlipBook"
{
	Properties
	{
		_Curvature("Curvaturel",Range(0.0,1))=1.0
		_Color("Color",Color)=(1,1,1,1)
		_Size("Size",Vector)=(2.0,2.0,0,0)
	}
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
		}

		Pass
		{
			Name "Flip Book"
			ZTest Always
			ZWrite On
			Cull Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct a2v
			{
				// float4 vertex:POSITION;
				float2 uv:TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal:TEXCOORD1;
				float3 tangent:TEXCOORD2;
			};

			TEXTURE2D_X(_ColorMapTex);

			// from shadergraph 
			// These are the samplers available in the HDRenderPipeline.
			// Avoid declaring extra samplers as they are 4x SGPR each on GCN.
			SAMPLER(sampler_Linear_Clamp);

			CBUFFER_START(UnityPerMaterial)
			float _StartTime;
			float _Speed;
			float _Curvature;
			half3 _Color;
			float2 _Size;
			CBUFFER_END

			float3 FlipAnimation(float2 uv, float time, float curvature, float2 size)
			{
				float param = 1 - time;
				float phi = param * (PI / 2 + curvature * uv.y);
				float v = uv.y / (1 + curvature / PI * param);
				return float3(0.5 - uv.x, cos(phi) * v - 0.5, sin(phi) * v) * size.xyy;
			}


			v2f vert(a2v IN)
			{
				v2f o;

				//Time Parameter[0,1]
				float overTime = _Time.y - _StartTime;
				float time = saturate(overTime * _Speed);

				//z offset by time
				float3 zOffset = float3(0, 0, overTime * 0.01);

				//uv
				float2 uv = IN.uv;
				float2 uvDelta = uv + float2(0, 0.001);

				float3 anim0 = FlipAnimation(uv, time, _Curvature, _Size);

				float3 anim1 = FlipAnimation(uvDelta, time, _Curvature, _Size);

				//normal&tangent
				float3 offsetAnim = anim1 - anim0;

				float3 normal = normalize(cross(offsetAnim, float3(1, 0, 0)));
				float3 tangent = normalize(offsetAnim);

				o.pos = float4(anim0 + zOffset, 1);
				o.uv = IN.uv;
				o.normal = normal;
				o.tangent = tangent;

				return o;
			}

			half4 frag(v2f IN) : SV_Target
			{
				//原来他PS里面是算BRDF的    所以有传入normal tangent   这里偷懒
				//原来还有SSAO  和  DepthPass   这里也没有
				//如果需要阴影可以做假


				float2 uv = IN.uv;
				uv.y = 1 - uv.y;
				half3 col = _Color * SAMPLE_TEXTURE2D(_ColorMapTex, sampler_Linear_Clamp, uv).rgb;
				col *= smoothstep(0.0, 0.1, uv.y);
				return half4(col, 1.0);
			}
			ENDHLSL
		}
	}
}