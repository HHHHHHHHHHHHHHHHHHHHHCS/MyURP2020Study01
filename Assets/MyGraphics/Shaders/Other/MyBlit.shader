Shader "MyRP/Other/MyBlit"
{
	Properties { }
	SubShader
	{
		Tags { "RenderType" = "Opaque" /*"RenderPipeline" = "UniversalPipeline"*/ }
		LOD 100
		
		Pass
		{
			Name "MyBlit"
			ZTest Always
			ZWrite Off
			Cull Off
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			TEXTURE2D_X(_SourceTex);
			SAMPLER(sampler_SourceTex);
			
			struct a2v
			{
				float4 positionHCS: POSITION;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float2 uv: TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
			};
			
			v2f vert(a2v v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				
				//位置和UV 在Mesh 创建的时候已经被设置好了
				//翻转Y是因为 https://issuetracker.unity3d.com/issues/lwrp-depth-texture-flipy
				//Unity在非OpenGL平台和渲染到渲染纹理时翻转投影矩阵。
				//如果URP渲染为RT——翻转Y
				//如果URP不渲染为RT，也不使用OpenGL进行渲染——不翻转
				o.positionCS = float4(v.positionHCS.xyz, 1.0);
				o.positionCS.y *= _ScaleBiasRt.x;
				o.uv = v.uv;
				
				//添加一个small epsilon  避免法线重建时候出现问题
				o.uv += 1.0e-6;
				
				return o;
			}
			
			half4 frag(v2f input): SV_Target
			{
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
				
				half4 col = SAMPLE_TEXTURE2D_X(_SourceTex, sampler_SourceTex, input.uv);
				
				return col;
			}
			ENDHLSL
			
		}
	}
}
