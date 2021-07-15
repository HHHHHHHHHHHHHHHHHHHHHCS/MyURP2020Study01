Shader "MyRP/TAA/VelocityBuffer"
{
	//	Properties
	//	{
	//	}

	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

	TEXTURE2D(_VelocityTex);
	SAMPLER(sampler_VelocityTex);


	float4 _Corner; // xy = ray to (1,1) corner of unjittered frustum at distance 1, zw = jitter at distance 1

	float4x4 _CurrV;
	float4x4 _CurrVP;
	float4x4 _CurrM;

	float4x4 _PrevVP;
	float4x4 _PrevM;


struct a2v
{
    uint vertexID : SV_VertexID;
};

struct v2f
{
    float4 pos: SV_POSITION;
    float2 uv: TEXCOORD0;
};

half4 DoEffect(v2f IN);

v2f vert(a2v v)
{
    v2f o;
    o.pos = GetFullScreenTriangleVertexPosition(v.vertexID);
    o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
    return o;
}

half4 frag(v2f IN):SV_Target
{
    return DoEffect(IN);
}
	
	ENDHLSL

	SubShader
	{

	}
}