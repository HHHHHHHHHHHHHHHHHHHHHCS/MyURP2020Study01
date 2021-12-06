#ifndef __TRAIL_SURFACE_COMMON_INCLUDE__
#define __TRAIL_SURFACE_COMMON_INCLUDE__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "SkinnerCommon.hlsl"

TEXTURE2D(_TrailPositionTex);
// float4 _TrailPositionTex_TexelSize;
TEXTURE2D(_TrailVelocityTex);
TEXTURE2D(_TrailOrthnormTex);

SAMPLER(s_linear_clamp_sampler);

//s_linear_clamp_sampler 允许做位置插值
// #define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)
#define SampleTex(textureName, coord2) SAMPLE_TEXTURE2D_LOD(textureName, s_point_clamp_sampler, coord2, 0)

// Line width modifier
half3 _LineWidth; // (max width, cutoff, speed-to-width / max width)

void GetAttrData(float4 vertex, out float3 positionWS, out float3 normalWS, out float speed)
{
    //fetch samples from the animation kernel
    // 为什么用linear 不用point   顶点数量不是 1:1的  所以  让位置有插值 效果更好
    // int2 uv = vertex.xy * _TrailPositionTex_TexelSize.zw;
    float2 uv = vertex.xy;
    float3 p = SampleTex(_TrailPositionTex, uv).xyz;
    float3 v = SampleTex(_TrailVelocityTex, uv).xyz;
    float4 b = SampleTex(_TrailOrthnormTex, uv);

    // Extract normal/binormal vector from the orthnormal sample.
    half3 normal = StereoInverseProjection(b.xy);
    half3 binormal = StereoInverseProjection(b.zw);

    speed = length(v);

    half width = _LineWidth.x * vertex.z * (1 - vertex.y);
    width *= saturate((speed - _LineWidth.y) * _LineWidth.z);

    positionWS = p + binormal * width;
    normalWS = normal;
}

#ifdef ForwardLitPass

// Base material properties
half3 _Albedo;
half _Smoothness;
half _Metallic;

// Color modifier
half _CutoffSpeed;
half _SpeedToIntensity;

struct a2v
{
    float4 vertex:POSITION;
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

    float id = IN.vertex.x;

    float3 positionWS;
    float3 normalWS;
    float speed;
    GetAttrData(IN.vertex, positionWS, normalWS, speed);

    half intensity = saturate((speed - _CutoffSpeed) * _SpeedToIntensity);

    o.worldPos = positionWS;
    o.pos = TransformWorldToHClip(o.worldPos);
    o.worldNormal = normalWS;
    o.color = ColorAnimation(id, intensity);
    o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
    OUTPUT_SH(o.worldNormal, o.sh);
    return o;
}


half4 ForwardLitFrag(v2f IN, half facing : VFACE):SV_Target
{
    UNITY_SETUP_INSTANCE_ID(IN);

    float3 normalWS = normalize(IN.worldNormal);//float3(0, 0, facing > 0 ? 1 : -1);

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
	float4 vertex: POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
	float4 positionCS: SV_POSITION;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


// x: global clip space bias, y: normal world space bias
float3 _LightDirection;


v2f ShadowCasterVert(a2v v)
{
	v2f o;

	UNITY_SETUP_INSTANCE_ID(v);
	UNITY_TRANSFER_INSTANCE_ID(v, o);

	float3 positionWS;
	float3 normalWS;
	float speed;
	GetAttrData(v.vertex, positionWS, normalWS, speed);

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
	float4 vertex: POSITION;
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

	float3 positionWS;
	float3 normalWS;
	float speed;
	GetAttrData(IN.vertex, positionWS, normalWS, speed);
				
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
    float4 vertex:POSITION;
    float2 texcoord1 :TEXCOORD1;
};

struct v2f
{
    float4 vertex:SV_POSITION;
    float4 transfer0:TEXCOORD0;
    float4 transfer1:TEXCOORD1;
};

TEXTURE2D(_TrailPrevPositionTex);
TEXTURE2D(_TrailPrevVelocityTex);
TEXTURE2D(_TrailPrevOrthnormTex);

float4x4 _NonJitteredVP;
float4x4 _PreviousVP;

v2f MotionVectorsVert(a2v IN)
{
    //fetch samples from the animation kernel
    // int2 pos = IN.vertex.xy * _TrailPositionTex_TexelSize.zw;
	float2 uv = IN.vertex.xy;
    float3 p0 = SampleTex(_TrailPrevPositionTex, uv).xyz;
    float3 v0 = SampleTex(_TrailPrevVelocityTex, uv).xyz;
    float4 b0 = SampleTex(_TrailPrevOrthnormTex, uv);
    float3 p1 = SampleTex(_TrailPositionTex, uv).xyz;
    float3 v1 = SampleTex(_TrailVelocityTex, uv).xyz;
    float4 b1 = SampleTex(_TrailOrthnormTex, uv);

    //Binormal Vector
    half3 binormal0 = StereoInverseProjection(b0.zw);
    half3 binormal1 = StereoInverseProjection(b1.zw);

    p0 = lerp(p0, p1, 0.5);
    p1 = lerp(v0, v1, 0.5);
    binormal0 = normalize(lerp(binormal0, binormal1, 0.5));

    //Line Width
    half width = _LineWidth.x * IN.vertex.z * (1 - IN.vertex.y);
    half width0 = width * saturate((length(v0) - _LineWidth.y) * _LineWidth.z);
    half width1 = width * saturate((length(v1) - _LineWidth.y) * _LineWidth.z);

    float4 vp0 = float4(p0 + binormal0 * width0, 1);
    float4 vp1 = float4(p1 + binormal1 * width1, 1);

    v2f o;
    o.vertex = TransformWorldToHClip(vp1.xyz);
    o.transfer0 = mul(_PreviousVP, vp0);
    o.transfer1 = mul(_NonJitteredVP, vp1);
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
