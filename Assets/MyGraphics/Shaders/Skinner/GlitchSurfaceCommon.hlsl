#ifndef __Glitch_SURFACE_COMMON_INCLUDE__
#define __Glitch_SURFACE_COMMON_INCLUDE__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "SkinnerCommon.hlsl"

TEXTURE2D(_GlitchPositionTex);
float4 _GlitchPositionTex_TexelSize;
TEXTURE2D(_GlitchVelocityTex);

SAMPLER(s_point_clamp_sampler);

// #define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)
#define SampleTex(textureName, coord2) SAMPLE_TEXTURE2D_LOD(textureName, s_point_clamp_sampler, coord2, 0)

float _BufferOffset;

// Glitch thresholds
float _EdgeThreshold;
float _AreaThreshold;

void GetAttrData(float4 texcoord, out float3 pos, out float3 nor, out float voff, out float dec)
{
    float id = texcoord.w;

    // V-coodinate offset for the position buffer.
    float voffs = UVRandom(id, 0) + _BufferOffset * _GlitchPositionTex_TexelSize.y;

    // U-coodinate offset: change randomly when V-offs wraps around.
    float uoffs = UVRandom(id + floor(voffs), 1);

    // Actually only the fractional part of V-offs is important.
    voffs = frac(voffs);

    float3 p0 = SampleTex(_GlitchPositionTex, float2(frac(texcoord.x + uoffs), voffs)).xyz;
    float3 p1 = SampleTex(_GlitchPositionTex, float2(frac(texcoord.y + uoffs), voffs)).xyz;
    float3 p2 = SampleTex(_GlitchPositionTex, float2(frac(texcoord.z + uoffs), voffs)).xyz;

    float3 center = (p0 + p1 + p2) / 3.0;
    float3 edges = float3(length(p1 - p0), length(p2 - p1), length(p0 - p2));

    // Soft thresholding by the edge lengths
    float3 ecull3 = saturate((edges - _EdgeThreshold) / _EdgeThreshold);
    float ecull = max(max(ecull3.x, ecull3.y), ecull3.z);

    // Soft thresholding by the triangle area
    float area = TriangleArea(edges.x, edges.y, edges.z);
    float acull = saturate((area - _AreaThreshold) / _AreaThreshold);

    // Finally, we can do something fun!
    float decay = pow(1 - voffs, 6);
    float scale = saturate(1 - max(ecull, acull)) * decay;

    pos = lerp(center, p0, scale);
    nor = normalize(cross(p1 - p0, p2 - p0));
    voff = voffs;
    dec = decay;
}

#ifdef ForwardLitPass

// Base material properties
half3 _Albedo;
half _Smoothness;
half _Metallic;

// Color modifier
half _ModDuration;


struct a2v
{
	float4 texcoord:TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 pos : SV_POSITION;
	half3 color : TEXCOORD0;
	float3 worldNormal : TEXCOORD1;
	float3 worldPos : TEXCOORD2;
	float4 shadowCoord : TEXCOORD3;
	float3 sh : TEXCOORD4;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

v2f ForwardLitVert(a2v IN)
{
	v2f o;
	UNITY_SETUP_INSTANCE_ID(IN);
	UNITY_TRANSFER_INSTANCE_ID(IN, o);

	float id = IN.texcoord.w;

	float3 vpos;
	float3 nor;
	float voffs;
	float decay;
	GetAttrData(IN.texcoord, vpos, nor, voffs, decay);

	half intensity = (1 - smoothstep(_ModDuration*0.5, _ModDuration, voffs)) * decay;

	o.worldPos = vpos.xyz;
	o.pos = TransformWorldToHClip(o.worldPos);
	o.worldNormal = nor;
	o.color = ColorAnimation(id, intensity);
	o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
	OUTPUT_SH(o.worldNormal, o.sh);
	return o;
}


half4 ForwardLitFrag(v2f IN, half facing : VFACE):SV_Target
{
	UNITY_SETUP_INSTANCE_ID(IN);

	float3 normalWS = float3(0, 0, facing > 0 ? 1 : -1);// normalize(IN.worldNormal);
	half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.worldPos));

	InputData inputData = (InputData)0;
	//PRDFForward.BuildInputData()
	inputData.positionWS = IN.worldPos;
	inputData.normalWS = normalWS; 
	inputData.viewDirectionWS = viewDirectionWS;
	inputData.shadowCoord = IN.shadowCoord;
	inputData.fogCoord = 0;
	inputData.vertexLighting = 1;
	inputData.bakedGI = SAMPLE_GI(0, IN.sh, normalWS);
	inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.pos);

	SurfaceData surface = (SurfaceData)0;
	surface.albedo = _Albedo;
	surface.metallic = _Metallic;
	surface.specular = 0;
	surface.smoothness = _Smoothness;
	surface.occlusion = 1.0;
	surface.emission = IN.color;
	surface.alpha = 1;
	surface.clearCoatMask = 0;
	surface.clearCoatSmoothness = 1;

	half4 color = UniversalFragmentPBR(inputData, surface);
	return color;
}

#endif

#ifdef ShadowCasterPass


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

struct a2v
{
	float4 texcoord:TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 positionCS: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


// x: global clip space bias, y: normal world space bias
float3 _LightDirection;


v2f ShadowCasterVert(a2v IN)
{
	v2f o;

	UNITY_SETUP_INSTANCE_ID(IN);
	UNITY_TRANSFER_INSTANCE_ID(IN, o);

	float3 vpos;
	float3 nor;
	float voffs;
	float decay;
	GetAttrData(IN.texcoord, vpos, nor, voffs, decay);

	float3 positionWS = vpos;
	float3 normalWS = nor.xyz;
	o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

	return o;
}

float4 ShadowCasterFrag(v2f IN): SV_Target
{
	UNITY_SETUP_INSTANCE_ID(IN);

	return 0;
}

#endif

#ifdef DepthOnlyPass

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct a2v
{
	float4 texcoord:TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 positionCS: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


v2f DepthOnlyVert(a2v IN)
{
	v2f o;

	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, o);

	float3 vpos;
	float3 nor;
	float voffs;
	float decay;
	GetAttrData(IN.texcoord, vpos, nor, voffs, decay);
				
	float3 positionWS = vpos;
	o.positionCS = TransformWorldToHClip(positionWS);

	return o;
}

float4 DepthOnlyFrag(v2f IN): SV_Target
{
	UNITY_SETUP_INSTANCE_ID(IN);

	return 0;
}

#endif

#ifdef MotionVectorsPass

struct a2v
{
    float4 texcoord0 :TEXCOORD0;
};

struct v2f
{
    float4 vertex:SV_POSITION;
    float4 transfer0:TEXCOORD0;
    float4 transfer1:TEXCOORD1;
};

TEXTURE2D(_GlitchPrevPositionTex);
TEXTURE2D(_GlitchPrevVelocityTex);

float4x4 _NonJitteredVP;
float4x4 _PreviousVP;

float3 GetPrevAttrData(float4 texcoord)
{
    float id = texcoord.w;

    // V-coodinate offset for the position buffer.
    float voffs = UVRandom(id, 0) + _BufferOffset * _GlitchPositionTex_TexelSize.y;

    // U-coodinate offset: change randomly when V-offs wraps around.
    float uoffs = UVRandom(id + floor(voffs), 1);

    // Actually only the fractional part of V-offs is important.
    voffs = frac(voffs);

    float3 p0 = SampleTex(_GlitchPrevPositionTex, float2(frac(texcoord.x + uoffs), voffs)).xyz;
    float3 p1 = SampleTex(_GlitchPrevPositionTex, float2(frac(texcoord.y + uoffs), voffs)).xyz;
    float3 p2 = SampleTex(_GlitchPrevPositionTex, float2(frac(texcoord.z + uoffs), voffs)).xyz;

    float3 center = (p0 + p1 + p2) / 3.0;
    float3 edges = float3(length(p1 - p0), length(p2 - p1), length(p0 - p2));

    // Soft thresholding by the edge lengths
    float3 ecull3 = saturate((edges - _EdgeThreshold) / _EdgeThreshold);
    float ecull = max(max(ecull3.x, ecull3.y), ecull3.z);

    // Soft thresholding by the triangle area
    float area = TriangleArea(edges.x, edges.y, edges.z);
    float acull = saturate((area - _AreaThreshold) / _AreaThreshold);

    // Finally, we can do something fun!
    float decay = pow(1 - voffs, 6);
    float scale = saturate(1 - max(ecull, acull)) * decay;

    return lerp(center, p0, scale);
}

v2f MotionVectorsVert(a2v IN)
{
    float4 uv = IN.texcoord0;
    float3 prevPos = GetPrevAttrData(uv);
    float3 currPos, nor;
    float voff, dec;
    GetAttrData(uv, currPos, nor, voff, dec);

    v2f o;
    o.vertex = TransformWorldToHClip(currPos);
    o.transfer0 = mul(_PreviousVP, float4(prevPos, 1.0));
    o.transfer1 = mul(_NonJitteredVP, float4(currPos, 1.0));
    return o;
}

half4 MotionVectorsFrag(v2f IN):SV_Target
{
    float3 hp0 = IN.transfer0.xyz / IN.transfer0.w;
    float3 hp1 = IN.transfer1.xyz / IN.transfer1.w;

    float2 vp0 = (hp0.xy + 1) / 2.0;
    float2 vp1 = (hp1.xy + 1) / 2.0;

    #if UNITY_UV_STARTS_AT_TOP
    vp0.y = 1 - vp0.y;
    vp1.y = 1 - vp1.y;
    #endif

    return half4(vp1 - vp0, 0, 1);
}

#endif

#endif
