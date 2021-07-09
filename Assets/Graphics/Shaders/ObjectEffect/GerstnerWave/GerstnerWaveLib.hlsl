#ifndef  __GERSTNER_WAVE_LIB_INCLUDE__
#define __GERSTNER_WAVE_LIB_INCLUDE__

float3 GerstnerWave(float4 wave, float3 p, inout float3 tangent, inout float3 binormal)
{
    float stepness = wave.z;
    float waveLength = wave.w;
    float k = TWO_PI / waveLength;
    float c = sqrt(9.8 / k);
    float2 d = normalize(wave.xy) * _Frequency;
    float f = k * (dot(d, p.xz) - c * _Time.y * _Speed);
    float a = stepness / k;

    tangent += float3(
        - d.x * d.x * (stepness * sin(f)),
        d.x * (stepness * cos(f)),
        - d.x * d.y * (stepness * sin(f))
    );
    binormal += float3(
        - d.x * d.y * (stepness * sin(f)),
        d.y * (stepness * cos(f)),
        - d.y * d.y * (stepness * sin(f))
    );
    return float3(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
}

float CalculateFresnel(float3 viewDir, float3 normal)
{
    float R_0 = (_AirRefractiveIndex - _WaterRefractiveIndex) / (_AirRefractiveIndex + _WaterRefractiveIndex);
    R_0 *= R_0;
    return R_0 + (1.0 - R_0) * pow(1.0 - saturate(dot(viewDir, normal)), _FresnelPower);
}

half3 Highlights(half roughness, half3 normalWS, half3 viewDirectionWS)
{
    Light mainLight = GetMainLight();
    half roughness2 = roughness * roughness;
    half3 halfDir = SafeNormalize(mainLight.direction + viewDirectionWS);
    half NoH = saturate(dot(normalize(normalWS), halfDir));
    half LoH = saturate(dot(mainLight.direction, halfDir));
    //GGX
    half d = NoH * NoH * (roughness2 - 1) + 1.0001;
    half LoH2 = LoH * LoH;
    half specularTerm = roughness2 / ((d * d) * max(0.1, LoH2) * (roughness + 0.5) * 4);
    specularTerm = min(specularTerm, 10);

    return specularTerm * mainLight.color * mainLight.distanceAttenuation;
}

float SubsurfaceScattering(float3 viewDir, float3 lightDir, float3 normalDir,
                           float frontSubsurfaceDistortion, float backSubsurfaceDistortion, float frontSSSIntensity,
                           float thickness)
{
    //分别计算正面和反面的次表面散射
    float3 frontLitDir = normalDir * frontSubsurfaceDistortion - lightDir;
    float3 backLitDir = normalDir * backSubsurfaceDistortion + lightDir;
    float frontsss = saturate(dot(viewDir, -frontLitDir));
    float backsss = saturate(dot(viewDir, -backLitDir));

    float result = saturate(frontsss * frontSSSIntensity + backsss) * thickness;
    return result;
}

#endif
