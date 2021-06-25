#ifndef  __IRIDESCENCE_LIGHTING_INCLUDE__
#define __IRIDESCENCE_LIGHTING_INCLUDE__


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

#include "IridescenceLitInput.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                         Helper Functions                                  //
///////////////////////////////////////////////////////////////////////////////


// XYZ to CIE 1931 RGB color space (using neutral E illuminant)
static const half3x3 XYZ_TO_RGB = half3x3(2.3706743, -0.5138850, 0.0052982,
                                          -0.9000405, 1.4253036, -0.0146949,
                                          -0.4706338, 0.0885814, 1.0093968);

// Square functions for cleaner code
inline float Sqr(float x) { return x * x; }
inline float2 Sqr(float2 x) { return x * x; }

// Depolarization functions for natural light
inline float Depol(float2 polV) { return 0.5 * (polV.x + polV.y); }
inline float3 DepolColor(float3 colS, float3 colP) { return 0.5 * (colS + colP); }

///////////////////////////////////////////////////////////////////////////////
//                         BRDF Functions                                    //
///////////////////////////////////////////////////////////////////////////////

struct BRDFDataAdvanced
{
    half3 diffuse;
    half3 specular;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;

    half normalizationTerm;
    half roughness2MinusOne;

    #ifdef _IRIDESCENCE
    half iridescenceThickness;
    half iridescenceEta2;
    half iridescenceEta3;
    half iridescenceKappa3;
    #endif
};

inline void InitializeBRDFDataAdvanced(SurfaceDataAdvanced surfaceData, out BRDFDataAdvanced outBRDFData)
{
    #ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(surfaceData.specular);
    half oneMinusReflectivity = 1.0 - reflectivity;

    outBRDFData.diffuse = surfaceData.albedo * (half3(1.0h, 1.0h, 1.0h) - surfaceData.specular);
    outBRDFData.specular = surfaceData.specular;

    #else
        half oneMinusReflectivity = OneMinusReflectivityMetallic(surfaceData.metallic);
        half reflectivity = 1.0 - oneMinusReflectivity;

        outBRDFData.diffuse = surfaceData.albedo * oneMinusReflectivity;
        outBRDFData.specular = lerp(kDieletricSpec.rgb, surfaceData.albedo, surfaceData.metallic);
    
    #endif

    outBRDFData.grazingTerm = saturate(surfaceData.smoothness + reflectivity);
    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.smoothness);
    outBRDFData.roughness = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN);
    outBRDFData.roughness2 = outBRDFData.roughness * outBRDFData.roughness;

    outBRDFData.normalizationTerm = outBRDFData.roughness * 4.0h + 2.0h;
    outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - 1.0h;

    #ifdef _IRIDESCENCE
    outBRDFData.iridescenceThickness = surfaceData.iridescenceThickness;
    outBRDFData.iridescenceEta2 = surfaceData.iridescenceEta2;
    outBRDFData.iridescenceEta3 = surfaceData.iridescenceEta3;
    outBRDFData.iridescenceKappa3 = surfaceData.iridescenceKappa3;
    #endif

    #ifdef _ALPHAPREMULTIPLY_ON
    outBRDFData.diffuse *= surfaceData.alpha;
    surfaceData.alpha = surfaceData.alpha * oneMinusReflectivity + reflectivity;
    #endif
}

#ifdef _IRIDESCENCE

// Evaluate the reflectance for a thin-film layer on top of a dielectric medum
// Based on the paper [LAURENT 2017] A Practical Extension to Microfacet Theory for the Modeling of Varying Iridescence
half3 ThinFilmIridescence(BRDFDataAdvanced brdfData, InputDataAdvanced inputData, float cosTheta1)
{
    float eta_1 = 1.0;
    float eta_2 = brdfData.iridescenceEta2;
    float eta_3 = brdfData.iridescenceEta3;
    float kappa_3 = brdfData.iridescenceKappa3;

    // iridescenceThickness unit is micrometer for this equation here. Mean 0.5 is 500nm.
    float Dinc = 2 * eta_2 * brdfData.iridescenceThickness;

    // Force eta_2 -> eta_1 when Dinc -> 0.0
    eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));

    float cosTheta2 = sqrt(1.0 - Sqr(eta_1 / eta_2) * (1 - Sqr(cosTheta1)));

    float R12, phi12;
    //TODO:
}

#endif

half3 GlobalIlluminationAdvanced(BRDFDataAdvanced brdfData, InputDataAdvanced inputData, half occlusion)
{
    half3 reflectVector = reflect(-inputData.viewDirectionWS, inputData.normalWS);

    half3 indirectDiffuse = inputData.bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);

    #ifdef _IRIDESCENCE
    float halfDir = SafeNormalize(float3(reflectVector) + float3(inputData.viewDirectionWS));
    float cosTheta1 = dot(halfDir, float3(reflectVector));

    half3 fresnelIridescence = ThinFilmIridescence(brdfData, inputData, cosTheta1);

    return EnvironmentBRDFIridescence(brdfData, indirectDiffuse, indirectSpecular, fresnelIridescence);

    #else

    half fresnelTerm = Pow4(1.0 - saturate(dot(inputData.normalWS, inputData.viewDirectionWS)));
    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);

    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentAdvanced(InputDataAdvanced inputData, SurfaceDataAdvanced surfaceData)
{
    BRDFDataAdvanced brdfData;
    InitializeBRDFDataAdvanced(surfaceData, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIlluminationAdvanced(brdfData, inputData, surfaceData.occlusion);
}

#endif
