#ifndef __4_DITHER_FINAL__
#define __4_DITHER_FINAL__

#include "4_PostProcessCommon_Final.hlsl"


TEXTURE2D(_DitheringTex);
float4 _Dithering_Coords;

half3 Dither(half3 color, float2 uv)
{
    uv = uv * _Dithering_Coords.xy + _Dithering_Coords.zw;
    float noise = SAMPLE_TEXTURE2D(_DitheringTex, sampler_Linear_Clamp, uv);
    noise = noise * 2.0 - 1.0;
    noise = FastSign(noise) * (1.0 - sqrt(1.0 - abs(noise)));

    #if UNITY_COLORSPACE_GAMMA
        color += noise / 255.0;
    #else
        color = SRGBToLinear(LinearToSRGB(color) + noise/255.0);
    #endif

    return color;
}

#endif
