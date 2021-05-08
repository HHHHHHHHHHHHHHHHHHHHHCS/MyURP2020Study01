#ifndef __INSCATTERING__
#define __INSCATTERING__

#ifndef SAMPLECOUNT_SKYBOX
#define SAMPLECOUNT_SKYBOX 32
#endif

#include "ScatteringMath.hlsl"


TEXTURE2D(_IntegralCPDensityLUT);
SAMPLER(sampler_IntegralCPDensityLUT);

TEXTURE2D(_LightShaft);
SAMPLER(sampler_LightShaft);

float2 _DensityScaleHeight;
float _PlanetRadius;
float _AtmosphereHeight;
float _SurfaceHeight;

float _MieG;
float3 _ScatteringR;
float3 _ScatteringM;
float3 _ExtinctionR;
float3 _ExtinctionM;
float _DistanceScale;

half3 _LightFromOuterSpace;
float _SunIntensity;
float _SunMieG;

void ApplyPhaseFunction(inout float3 scatterR, inout float3 scatterM, float cosAngle)
{
    scatterR *= RayleighPhase(cosAngle);
    scatterM *= MiePhaseHGCS(cosAngle, _MieG);
}
    
float3 RenderSun(float3 scatterM, float cosAngle)
{
    return scatterM * MiePhaseHG(cosAngle, _SunMieG) * 0.003;
}

void GetAtmosphereDensity(float3 position, float3 planetCenter, float3 lightDir, out float2 densityAtP, out float2 particleDensityCP)
{
    float height = length(position - planetCenter) - _PlanetRadius;
    densityAtP = ParticleDensity(height, _DensityScaleHeight.xy);
        
    float cosAngle = dot(normalize(position - planetCenter), lightDir.xyz);
        
    particleDensityCP = SAMPLE_TEXTURE2D_LOD(_IntegralCPDensityLUT, sampler_IntegralCPDensityLUT, float2(cosAngle * 0.5 + 0.5, (height / _AtmosphereHeight)), 0).xy;
}

void ComputeLocalInScattering(float2 densityAtP, float2 particleDensityCP, float2 particleDensityAP,
                              out float3 localInScatterR, out float3 localInScatterM)
{
    float2 particleDensityCPA = particleDensityAP + particleDensityCP;

    float3 tr = particleDensityCPA.x * _ExtinctionR;
    float3 tm = particleDensityCPA.y * _ExtinctionM;

    float3 extinction = exp(-(tr + tm));

    localInScatterR = densityAtP.x * extinction;
    localInScatterM = densityAtP.y * extinction;
}


float3 IntegrateInScattering(float3 rayStart, float3 rayDir, float rayLength, float3 planetCenter, float distanceScale,
                             float3 lightDir, float sampleCount, out float3 extinction)
{
    rayLength *= distanceScale;
    float3 step = rayDir * (rayLength / sampleCount);
    float stepSize = length(step); //*distanceScale

    float2 particleDensityAP = 0;
    float3 scatterR = 0;
    float3 scatterM = 0;

    float2 densityAtP;
    float2 particleDensityCP;

    float2 preDensityAtP;
    float3 preLocalInScatterR, preLocalInScatterM;
    GetAtmosphereDensity(rayStart, planetCenter, lightDir, preDensityAtP, particleDensityCP);
    ComputeLocalInScattering(preDensityAtP, particleDensityCP, particleDensityAP, preLocalInScatterR,
                             preLocalInScatterM);

    //TODO loop vs Unroll?
    [loop]
    for (float s = 1.0; s < sampleCount; s += 1)
    {
        float3 p = rayStart + step * s;

        GetAtmosphereDensity(p, planetCenter, lightDir, densityAtP, particleDensityCP);
        particleDensityAP += (densityAtP + preDensityAtP) * (stepSize / 2.0);

        preDensityAtP = densityAtP;

        float3 localInScatterR, localInScatterM;
        ComputeLocalInScattering(densityAtP, particleDensityCP, particleDensityAP, localInScatterR, localInScatterM);

        scatterR += (localInScatterR + preLocalInScatterR) * (stepSize / 2.0);
        scatterM += (localInScatterM + preLocalInScatterM) * (stepSize / 2.0);


        preLocalInScatterR = localInScatterR;
        preLocalInScatterM = localInScatterM;
    }

    float cosAngle = dot(rayDir, lightDir.xyz);

    ApplyPhaseFunction(scatterR, scatterM, cosAngle);

    float3 lightInScatter = (scatterR * _ScatteringR + scatterM * _ScatteringM) * _LightFromOuterSpace.xyz;
    #if defined(_RENDERSUN)
    lightInScatter += RenderSun(scatterR, cosAngle) * _SunIntensity;
    #endif

    extinction = exp(-(particleDensityAP.x * _ExtinctionR + particleDensityAP.y * _ExtinctionM));

    return lightInScatter.xyz;
}

half4 CalcInScattering(float3 positionOS)
{
    float3 rayStart = _WorldSpaceCameraPos.xyz;
    float3 rayDir = normalize(TransformObjectToWorld(positionOS));
    float3 planetCenter = float3(0, -_PlanetRadius, 0);
    float3 lightDir = _MainLightPosition.xyz;

    float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
    float rayLength = intersection.y;

    intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
    if (intersection.x >= 0)
    {
        rayLength = min(rayLength, intersection.x);
    }

    float3 extinction;

    float3 inscattering = IntegrateInScattering(rayStart, rayDir, rayLength, planetCenter, 1, lightDir,
                                                SAMPLECOUNT_SKYBOX, extinction);
    return float4(inscattering, 1);
}


#endif
