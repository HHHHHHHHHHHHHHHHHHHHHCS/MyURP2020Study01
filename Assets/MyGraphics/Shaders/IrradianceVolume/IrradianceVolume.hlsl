#ifndef __IRRADIANCE_VOLUME_INCLUDED__
#define __IRRADIANCE_VOLUME_INCLUDED__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE3D(_VolumeTex0);
TEXTURE3D(_VolumeTex1);
TEXTURE3D(_VolumeTex2);
TEXTURE3D(_VolumeTex3);
TEXTURE3D(_VolumeTex4);
TEXTURE3D(_VolumeTex5);

SAMPLER(s_linear_clamp_sampler);

CBUFFER_START(IrradianceVolume)
float3 _VolumeSize;
float3 _VolumePosition;
float _VolumeInterval;
CBUFFER_END

half3 GetAmbientColor(float3 normal, float3 coord)
{
    float3 nSquared = normal * normal;
    half3 colorX = normal.x >= 0.0
                       ? SAMPLE_TEXTURE3D_LOD(_VolumeTex0, s_linear_clamp_sampler, coord, 0).rgb
                       : SAMPLE_TEXTURE3D_LOD(_VolumeTex1, s_linear_clamp_sampler, coord, 0).rgb;
    half3 colorY = normal.y >= 0.0
                       ? SAMPLE_TEXTURE3D_LOD(_VolumeTex2, s_linear_clamp_sampler, coord, 0).rgb
                       : SAMPLE_TEXTURE3D_LOD(_VolumeTex3, s_linear_clamp_sampler, coord, 0).rgb;
    half3 colorZ = normal.z >= 0.0
                       ? SAMPLE_TEXTURE3D_LOD(_VolumeTex4, s_linear_clamp_sampler, coord, 0).rgb
                       : SAMPLE_TEXTURE3D_LOD(_VolumeTex5, s_linear_clamp_sampler, coord, 0).rgb;

    half3 col = nSquared.x * colorX + nSquared.y * colorY + nSquared.z * colorZ;

    return col;
}

half3 GetIrradiance(float3 position, float3 normal)
{
    float3 pos = position - _VolumePosition;
    float3 size = (_VolumeSize * 2 + 1) * _VolumeInterval;
    float3 coord = pos / size;
    float3 direction = reflect(-_MainLightPosition.xyz, normal);

    half3 color = GetAmbientColor(direction, coord);

    return color;
}

#endif
