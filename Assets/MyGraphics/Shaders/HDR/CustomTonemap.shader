Shader "MyRP/HDR/CustomTonemap"
{
	HLSLINCLUDE
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
	
	#include "TonemapCommon.hlsl"
	
	struct a2v
	{
		float4 vertex: POSITION;
		float2 uv: TEXCOORD0;
	};
	
	struct v2f
	{
		float4 pos: SV_POSITION;
		float2 uv: TEXCOORD0;
	};
	
	float _Exposure;
	float _Saturation;
	float _Contrast;
	
	
	v2f vert(a2v v)
	{
		v2f o = (v2f)0;
		o.pos = v.vertex;
		o.pos.y *= _ScaleBiasRt.x;
		
		o.uv = v.uv;
		return o;
	}
	
	float4 frag(v2f i): SV_TARGET
	{
		float3 color = SampleSceneColor(i.uv);
		color.rgb = ColorCorrect(color.rgb, _Saturation, _Contrast, _Exposure);
		color.rgb = ACESFilm(color.rgb);
		return float4(color, 1.0);
	}
	
	ENDHLSL
	
	SubShader
	{
		Cull Off
		ZWrite Off
		ZTest Always
		
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			ENDHLSL
			
		}
	}
}
