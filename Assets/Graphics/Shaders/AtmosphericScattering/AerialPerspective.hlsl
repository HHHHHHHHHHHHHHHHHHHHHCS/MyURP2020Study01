#ifndef __APPLY_SCATTERING__
#define __APPLY_SCATTERING__

#include "ScatteringMath.hlsl"

float _MieG;
float3 _ScatteringR;
float3 _ScatteringM;
float3 _ExtinctionR;
float3 _ExtinctionM;
float _DistanceScale;

//需要include unity-render.pipeline
TEXTURE2D(_LightShaft);
SAMPLER(sampler_LightShaft);

void ApplyScattering(inout half4 color, float3 positionWS, float2 screenPos)
{
    // float height = _WorldSpaceCameraPos.y;
    float3 viewDir = positionWS - _WorldSpaceCameraPos.xyz;
    float distance = length(viewDir);
    viewDir /= distance;

    float cosAngle = dot(viewDir, _MainLightPosition.xyz);

    float3 scatCoef = _ScatteringR + _ScatteringM;
    float3 scatAngularCoef = _ScatteringR * RayleignPhase(cosAngle) + _ScatteringM * MiePhaseHG(cosAngle, _MieG);

    float3 extinction = exp(-(_ExtinctionR + _ExtinctionM) * distance * _DistanceScale);
    float3 inscattering = _MainLightColor.rgb * (1 - extinction) * scatAngularCoef / scatCoef;

    #ifdef _LIGHT_SHAFT
        half occlusion = SAMPLE_TEXTURE2D(_LightShaft,sampler_LightShaft,screenPos.xy)matrix;
        //occlusion = occlusion * occlusion * occlusion;
        inscattering.rgb *= occlusion;
    #endif

    #ifdef _DEBUG_INSCATTERING
    color.rgb = inscattering;
    #elif _DEBUG_EXTINGCTION
    color.rgb = extinction;
    #else
    color.rgb = color.rgb * extinction + inscattering;
    #endif
}

#ifdef _AERIAL_PERSPECTIVE
#define APPLY_SCATTERING(color, positionWS, screenUv) ApplyScattering(color, positionWS.xyz, screenUv);
#else
#define APPLY_SCATTERING(color, positionWS, screenUv)
#endif

#endif
