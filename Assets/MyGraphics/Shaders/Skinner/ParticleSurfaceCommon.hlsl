#ifndef __PARTICLE_SURFACE_COMMON_INCLUDE__
#define __PARTICLE_SURFACE_COMMON_INCLUDE__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

#include "SkinnerCommon.hlsl"

TEXTURE2D(_ParticlePositionTex);
float4 _ParticlePositionTex_TexelSize;
TEXTURE2D(_ParticleVelocityTex);
TEXTURE2D(_ParticleRotationTex);

#define SampleTex(textureName, coord2) LOAD_TEXTURE2D(textureName, coord2)

// Scale modifier
float2 _Scale; // (min, max)
// Color modifier
half _CutoffSpeed;
half _SpeedToIntensity;

struct AttrData
{
    float id; //in
    float3 vertex;
    float3 normal;
    float4 tangent;
    float speed; //out
};

void GetAttrData(inout AttrData data)
{
    int2 pos = int2(data.id * _ParticlePositionTex_TexelSize.z, 0.0);
    float4 p = SampleTex(_ParticlePositionTex, pos);
    float4 v = SampleTex(_ParticleVelocityTex, pos);
    float4 r = SampleTex(_ParticleRotationTex, pos);

    data.speed = length(v.xyz);
    //p.w [-0.5,0.5]   v.w 是初始速度
    half scale = ParticleScale(data.id, p.w, v.w, _Scale);

    data.vertex = RotateVector(data.vertex, r) * scale + p.xyz;
    data.normal = RotateVector(data.normal, r);
    #ifdef SKINNER_TEXTURED
    data.tangent.xyz = RotateVector(data.tangent.xyz, r);
    #endif
}

//ForwardLitPass
//------------------------------
#ifdef ForwardLitPass

#if defined(SKINNER_TEXTURED)
TEXTURE2D(_AlbedoMap);
SAMPLER(sampler_AlbedoMap);
TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);
half _NormalScale;
#endif


// Base material properties
half3 _Albedo;
half _Smoothness;
half _Metallic;


struct a2v
{
    float4 vertex:POSITION;
    float3 normal:NORMAL;
    float4 tangent:TANGENT;
    float2 uv:TEXCOORD0;
    float id:TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 pos : SV_POSITION;
    float3 worldPos : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 worldTangent : TEXCOORD2;
    float3 worldBinormal : TEXCOORD3;
    float3 worldNormal : TEXCOORD4;
    half3 color : TEXCOORD5;
    float4 shadowCoord : TEXCOORD6;
    float3 sh : TEXCOORD7;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

v2f ForwardLitVert(a2v IN)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(IN);
    UNITY_TRANSFER_INSTANCE_ID(IN, o);

    float id = IN.id;

    AttrData data = (AttrData)0;
    data.id = id;
    data.vertex = IN.vertex.xyz;
    data.normal = IN.normal;
    data.tangent = IN.tangent;

    GetAttrData(data);

    half intensity = saturate((data.speed - _CutoffSpeed) * _SpeedToIntensity);

    o.worldPos = data.vertex;
    o.pos = TransformWorldToHClip(o.worldPos);
    o.uv = IN.uv;
    o.worldTangent = data.tangent.xyz;
    o.worldNormal = data.normal;
    o.worldBinormal = cross(o.worldNormal, o.worldTangent) * data.tangent.w * GetOddNegativeScale();
    o.color = ColorAnimation(id, intensity);
    o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
    OUTPUT_SH(o.worldNormal, o.sh);
    return o;
}


half4 ForwardLitFrag(v2f IN, half facing : VFACE):SV_Target
{
    UNITY_SETUP_INSTANCE_ID(IN);

    float3 normal = float3(0, 0, 1);
    half3 albedo = _Albedo;
    #ifdef SKINNER_TEXTURED
    albedo *= SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, IN.uv).rgb;
    half3 n = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv), _NormalScale);
    #ifdef SKINNER_TWO_SIDED
    normal = n * (facing > 0? 1: -1);
    #else
    normal = n;
    #endif
    #else
    #ifdef SKINNER_TWO_SIDED
    normal = half3(0, 0, facing>0?1:-1);
    #endif
    #endif

    float3 worldNormal;
    worldNormal.x = dot(float3(IN.worldTangent.x, IN.worldBinormal.x, IN.worldNormal.x), normal);
    worldNormal.y = dot(float3(IN.worldTangent.y, IN.worldBinormal.y, IN.worldNormal.y), normal);
    worldNormal.z = dot(float3(IN.worldTangent.z, IN.worldBinormal.z, IN.worldNormal.z), normal);

    half3 viewDirectionWS = normalize(GetWorldSpaceViewDir(IN.worldPos));

    InputData inputData = (InputData)0;
    //PRDFForward.BuildInputData()
    inputData.positionWS = IN.worldPos;
    inputData.normalWS = worldNormal;
    inputData.viewDirectionWS = viewDirectionWS;
    inputData.shadowCoord = IN.shadowCoord;
    inputData.fogCoord = 0;
    inputData.vertexLighting = 1;
    inputData.bakedGI = SAMPLE_GI(0, IN.sh, IN.worldNormal);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.pos);

    SurfaceData surface = (SurfaceData)0;
    surface.albedo = albedo;
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


//ShadowCasterPass
//------------------------------
#ifdef ShadowCasterPass

struct a2v
{
    float4 vertex:POSITION;
    float3 normal:NORMAL;
    float4 tangent:TANGENT;
    float2 uv:TEXCOORD0;
    float id:TEXCOORD1;
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

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);

    float id = IN.id;

    AttrData data = (AttrData)0;
    data.id = id;
    data.vertex = IN.vertex.xyz;
    data.normal = IN.normal;
    data.tangent = IN.tangent;
    
    GetAttrData(data);

    float3 positionWS = data.vertex;
    float3 normalWS = data.normal;
    o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

    return o;
}

float4 ShadowCasterFrag(v2f IN): SV_Target
{
    UNITY_SETUP_INSTANCE_ID(IN);

    return 0;
}

#endif


//DepthOnlyPass
//------------------------------
#ifdef DepthOnlyPass

struct a2v
{
    float4 vertex:POSITION;
    float3 normal:NORMAL;
    float4 tangent:TANGENT;
    float2 uv:TEXCOORD0;
    float id:TEXCOORD1;
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

    float id = IN.id;

    AttrData data = (AttrData)0;
    data.id = id;
    data.vertex = IN.vertex.xyz;
    data.normal = IN.normal;
    data.tangent = IN.tangent;
    
    GetAttrData(data);

    float3 positionWS = data.vertex.xyz;
    o.positionCS = TransformWorldToHClip(positionWS);

    return o;
}

float4 DepthOnlyFrag(v2f IN): SV_Target
{
    UNITY_SETUP_INSTANCE_ID(IN);

    return 0;
}

#endif


//MotionVectorsPass
//------------------------------
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

TEXTURE2D(_ParticlePrevPositionTex);
TEXTURE2D(_ParticlePrevRotationTex);

float4x4 _NonJitteredVP;
float4x4 _PreviousVP;

v2f MotionVectorsVert(a2v IN)
{
    // Particle ID
    float id = IN.texcoord1.x;

    //fetch samples from the animation kernel
    int2 uv = int2(id * _ParticlePositionTex_TexelSize.x, 0);
    float4 p0 = SampleTex(_ParticlePrevPositionTex, uv);
    float4 r0 = SampleTex(_ParticlePrevRotationTex, uv);
    float4 p1 = SampleTex(_ParticlePositionTex, uv);
    float4 r1 = SampleTex(_ParticleRotationTex, uv);
    float4 v1 = SampleTex(_ParticleVelocityTex, uv);

    // Scale animation
    half s0 = ParticleScale(id, p0.w + 0.5, v1.w, _Scale); // ok for borrowing V1.w?
    half s1 = ParticleScale(id, p1.w + 0.5, v1.w, _Scale);

    float4 vp0 = float4(RotateVector(IN.vertex.xyz, r0) * s0 + p0.xyz, 1);
    float4 vp1 = float4(RotateVector(IN.vertex.xyz, r1) * s1 + p1.xyz, 1);

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
