#ifndef __SKINNER_COMMON_INCLUDE__
#define __SKINNER_COMMON_INCLUDE__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

// Seed for PRNG
float _RandomSeed;

// Common color animation
half _BaseHue;
half _HueRandomness;
half _Saturation;
half _Brightness;
half _EmissionProb;
half _HueShift;
half _BrightnessOffs;

// PRNG function
float UVRandom(float2 uv, float salt)
{
    uv += float2(salt, _RandomSeed);
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// Quaternion multiplication
// http://mathworld.wolfram.com/Quaternion.html
float4 QMult(float4 q1, float4 q2)
{
    float3 ijk = q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz);
    return float4(ijk, q1.w * q2.w - dot(q1.xyz, q2.xyz));
}


half3 StereoInverseProjection(half2 p)
{
    float d = 2 / (dot(p.xy, p.xy) + 1);
    return float3(p.xy * d, 1 - d);
}


// Hue to RGB convertion
half3 HueToRGB(half h)
{
    h = frac(h);
    half r = abs(h * 6 - 3) - 1;
    half g = 2 - abs(h * 6 - 2);
    half b = 2 - abs(h * 6 - 4);
    half3 rgb = saturate(half3(r, g, b));
    #if UNITY_COLORSPACE_GAMMA
    return rgb;
    #else
    return SRGBToLinear(rgb);
    #endif
}

half3 ColorAnimation(float id, half intensity)
{
    // Low frequency oscillation with half-wave rectified sinusoid.
    half phase = UVRandom(id, 30) * 32 + _Time.y * 4;
    half lfo = abs(sin(phase * PI));

    // Switch LFO randomly at zero-cross points.
    lfo *= UVRandom(id + floor(phase), 31) < _EmissionProb;

    // Hue animation.
    half hue = _BaseHue + UVRandom(id, 32) * _HueRandomness + _HueShift * intensity;

    // Convert to RGB.
    half3 rgb = lerp(1, HueToRGB(hue), _Saturation);

    // Apply brightness.
    return rgb * (_Brightness * lfo + _BrightnessOffs * intensity);
}


#endif
