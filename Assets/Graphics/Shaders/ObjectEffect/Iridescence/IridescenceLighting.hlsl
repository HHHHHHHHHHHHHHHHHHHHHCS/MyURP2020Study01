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

//BSDF.hlsl 也有EvalSensitivity函数  但是多了srgb的转换  我们需要的是rgb 而且  rgb的转换统一在后面转换
// Ref: https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html
// Evaluation XYZ sensitivity curves in Fourier space
float3 MyEvalSensitivity(float opd, float shift)
{
    // Use Gaussian fits, given by 3 parameters: val, pos and var
    float phase = 2.0 * PI * opd * 1e-6;
    float3 val = float3(5.4856e-13, 4.4201e-13, 5.2481e-13);
    float3 pos = float3(1.6810e+06, 1.7953e+06, 2.2084e+06);
    float3 var = float3(4.3278e+09, 9.3046e+09, 6.6121e+09);
    float3 xyz = val * sqrt(2.0 * PI * var) * cos(pos * phase + shift) * exp(-var * phase * phase);
    xyz.x += 9.7470e-14 * sqrt(2.0 * PI * 4.5282e+09) * cos(2.2399e+06 * phase + shift) * exp(
        -4.5282e+09 * phase * phase);
    xyz /= 1.0685e-7;

    // Convert to linear sRGb color space here.
    // EvalIridescence works in linear sRGB color space and does not switch...
    // real3 srgb = mul(XYZ_2_REC709_MAT, xyz);
    return xyz;
}

///////////////////////////////////////////////////////////////////////////////
//                         BRDF Functions                                    //
///////////////////////////////////////////////////////////////////////////////

struct BRDFDataAdvanced
{
    half3 diffuse;
    half3 specular;
    float reflectivity;
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

inline void BRDFDataAdvancedToNormal(in BRDFDataAdvanced advanced, out BRDFData normal)
{
    normal.diffuse = advanced.diffuse;
    normal.specular = advanced.specular;
    normal.reflectivity = advanced.reflectivity;
    normal.perceptualRoughness = advanced.perceptualRoughness;
    normal.roughness = advanced.roughness;
    normal.roughness2 = advanced.roughness2;
    normal.grazingTerm = advanced.grazingTerm;
    normal.normalizationTerm = advanced.normalizationTerm;
    normal.roughness2MinusOne = advanced.roughness2MinusOne;
}

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

    outBRDFData.reflectivity = reflectivity;
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

float GGX(float NdotH, float a)
{
    float a2 = Sqr(a);
    return a2 / (PI * Sqr(Sqr(NdotH) * (a2 - 1) + 1));
}

float SmithG1_GGX(float NdotV, float a)
{
    float a2 = Sqr(a);
    return 2 / (1 + sqrt(1 + a2 * (1 - Sqr(NdotV)) / Sqr(NdotV)));
}

float SmithG_GGX(float NdotL, float NdotV, float a)
{
    return SmithG1_GGX(NdotL, a) * SmithG1_GGX(NdotV, a);
}


// Fresnel equations for dielectric/dielectric interfaces.
void FresnelDielectric(in float ct1, in float n1, in float n2,
                       out float2 R, out float2 phi)
{
    float st1 = (1 - ct1 * ct1);
    float nr = n1 / n2;

    //total reflection
    if (Sqr(nr) * st1 > 1)
    {
        float2 R = float2(1, 1);
        phi = 2.0 * atan2(-Sqr(nr) * sqrt(st1 - 1.0 / Sqr(nr)) / ct1,
                          -sqrt(st1 - 1.0 / Sqr(nr)) / ct1);
    }
    else
    {
        //Transmission & Reflection
        float ct2 = sqrt(1 - Sqr(nr) * st1);
        float2 r = float2((n2 * ct1 - n1 * ct2) / (n2 * ct1 + n1 * ct2),
                          (n1 * ct1 - n2 * ct2) / (n1 * ct1 + n2 * ct2));
        phi.x = (r.x < 0.0) ? PI : 0.0;
        phi.y = (r.y < 0.0) ? PI : 0.0;
        R = Sqr(r);
    }
}

// Fresnel equations for dielectric/conductor interfaces.
void FresnelConductor(in float ct1, in float n1, in float n2, in float k,
                      out float2 R, out float2 phi)
{
    if (k == 0)
    {
        FresnelDielectric(ct1, n1, n2, R, phi);
        return;
    }

    float A = Sqr(n2) * (1 - Sqr(k)) - Sqr(n1) * (1 - Sqr(ct1));
    float B = sqrt(Sqr(A) + Sqr(2 * Sqr(n2) * k));
    float U = sqrt((A + B) / 2.0);
    float V = sqrt((B - A) / 2.0);

    R.y = (Sqr(n1 * ct1 - U) + Sqr(V)) / (Sqr(n1 * ct1 + U) + Sqr(V));
    phi.y = atan2(2 * n1 * V * ct1, Sqr(U) + Sqr(V) - Sqr(n1 * ct1)) + PI;

    R.x = (Sqr(Sqr(n2) * (1 - Sqr(k)) * ct1 - n1 * U) + Sqr(2 * Sqr(n2) * k * ct1 - n1 * V))
        / (Sqr(Sqr(n2) * (1 - Sqr(k)) * ct1 + n1 * U) + Sqr(2 * Sqr(n2) * k * ct1 + n1 * V));
    phi.x = atan2(2 * n1 * Sqr(n2) * ct1 * (2 * k * U - (1 - Sqr(k)) * V),
                  Sqr(Sqr(n2) * (1 + Sqr(k)) * ct1) - Sqr(n1) * (Sqr(U) + Sqr(V)));
}

half3 EnvironmentBRDFIridescence(BRDFDataAdvanced brdfData, half3 indirectDiffuse, half3 indirectSpecular,
                                 half3 fresnelIridescent)
{
    half3 c = indirectDiffuse * brdfData.diffuse;
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular * lerp(brdfData.specular * fresnelIridescent, brdfData.grazingTerm,
                                                    fresnelIridescent);
    return c;
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

    //first interface
    float2 R12, phi12;
    FresnelDielectric(cosTheta1, eta_1, eta_2, R12, phi12);
    float2 R21 = R12;
    float2 T121 = float2(1.0, 1.0) - R12;
    float2 phi21 = float2(PI,PI) - phi12;

    //second interface
    float2 R23, phi23;
    FresnelConductor(cosTheta2, eta_2, eta_3, kappa_3, R23, phi23);

    //phase shift
    float OPD = Dinc * cosTheta2;
    float2 phi2 = phi21 + phi23;

    //compound terms
    float3 I = float3(0, 0, 0);
    float2 R123 = clamp(R12 * R23, 1e-5, 0.9999);
    float2 r123 = sqrt(R123);
    float2 Rs = Sqr(T121) * R23 / (float2(1.0, 1.0) - R123);

    //reflectance term for m=0(DC term amplitude)
    float2 C0 = R12 + Rs;
    float3 S0 = MyEvalSensitivity(0.0, 0.0);
    I += Depol(C0) * S0;

    //reflectance term for m>0 (pairs of diracs)
    float2 Cm = Rs - T121;

    UNITY_UNROLLX(3)
    for (int m = 1; m <= 3; m++)
    {
        Cm *= r123;
        float3 SmS = 2.0 * MyEvalSensitivity(m * OPD, m * phi2.x);
        float3 SmP = 2.0 * MyEvalSensitivity(m * OPD, m * phi2.y);
        I += DepolColor(Cm.x * SmS, Cm.y * SmP);
    }

    //convert back to rgb reflectance
    I = max(mul(I, XYZ_TO_RGB), float3(0.0, 0.0, 0.0));

    return I;
}

half3 DirectBRDFIridescence(BRDFDataAdvanced brdfData, InputDataAdvanced inputData, half3 lightDirectionWS)
{
    //compute dot products
    float NdotL = dot(inputData.normalWS, lightDirectionWS);
    float NdotV = dot(inputData.normalWS, inputData.viewDirectionWS);

    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(inputData.viewDirectionWS));
    float NdotH = dot(inputData.normalWS, halfDir);
    float cosTheta1 = dot(halfDir, float3(lightDirectionWS));

    half3 I = ThinFilmIridescence(brdfData, inputData, cosTheta1);
    //Microfacet BRDF formula
    float D = GGX(NdotH, brdfData.perceptualRoughness);
    float G = SmithG_GGX(NdotL, NdotV, brdfData.perceptualRoughness);

    half3 diffuseTerm = brdfData.diffuse;
    half3 specularTerm = D * G * I / (4 * NdotL * NdotV);

    half3 color = specularTerm * brdfData.specular + diffuseTerm;

    return color;
}

#endif


// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half3 DirectBDRFAdvanced(BRDFDataAdvanced brdfData, InputDataAdvanced inputData, half3 lightDirectionWS)
{
    #ifndef _SPECULARHIGHLIGHTS_OFF
    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(inputData.viewDirectionWS));

    float NoH = saturate(dot(inputData.normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness² / ( NoH² * (roughness² - 1) + 1 )²
    // V * F = 1.0 / ( LoH² * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness² / ( NoH² * (roughness² - 1) + 1 )² * (LoH² * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);
    half3 diffuseTerm = brdfData.diffuse;

    // on mobiles (where half actually means something) denominator have risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
    #if defined (SHADER_API_MOBILE)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
    #endif

    half3 color = specularTerm * brdfData.specular + diffuseTerm;
    return color;
    #else
    return brdfData.diffuse;
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                      Global Illumination                                  //
///////////////////////////////////////////////////////////////////////////////

half3 GlobalIlluminationAdvanced(BRDFDataAdvanced brdfData, InputDataAdvanced inputData, half occlusion)
{
    half3 reflectVector = reflect(-inputData.viewDirectionWS, inputData.normalWS);

    half3 indirectDiffuse = inputData.bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);

    #ifdef _IRIDESCENCE
    float3 halfDir = SafeNormalize(float3(reflectVector) + float3(inputData.viewDirectionWS));
    float cosTheta1 = dot(halfDir, float3(reflectVector));

    half3 fresnelIridescence = ThinFilmIridescence(brdfData, inputData, cosTheta1);

    return EnvironmentBRDFIridescence(brdfData, indirectDiffuse, indirectSpecular, fresnelIridescence);

    #else

    BRDFData bd;
    BRDFDataAdvancedToNormal(brdfData,bd);
    half fresnelTerm = Pow4(1.0 - saturate(dot(inputData.normalWS, inputData.viewDirectionWS)));
    return EnvironmentBRDF(bd, indirectDiffuse, indirectSpecular, fresnelTerm);

    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                      Lighting Functions                                   //
///////////////////////////////////////////////////////////////////////////////

half3 LightingAdvanced(BRDFDataAdvanced brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation,
                       InputDataAdvanced inputData)
{
    half NdotL = saturate(dot(inputData.normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);

    #if _IRIDESCENCE
    return DirectBRDFIridescence(brdfData, inputData, lightDirectionWS) * radiance;
    #else
    return DirectBRDFAdvanced(brdfData, inputData, lightDirectionWS) * radiance;
    #endif
}

half3 LightingAdvanced(BRDFDataAdvanced brdfData, Light light, InputDataAdvanced inputData)
{
    return LightingAdvanced(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation,
                            inputData);
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
    color += LightingAdvanced(brdfData, mainLight, inputData);

    #ifdef _ADDITIONAL_LIGHTS
        int pixelLightCount = GetAdditionalLightsCount();
        for(int i = 0;i<pixelLightCount;i++)
        {
            Light light = GetAdditionalLight(i, inputData.positionWS);
            color += LightingAdvanced(brdfData, light, inputData);
        }
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        color += inputData.vertexLighting * brdfData.diffuse;
    #endif

    color += surfaceData.emission;
    return half4(color, surfaceData.alpha);
}

#endif
