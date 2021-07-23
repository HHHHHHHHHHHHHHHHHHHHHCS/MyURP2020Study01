#ifndef  __SSSS_PBS_LIGHTING_INCLUDE__
#define __SSSS_PBS_LIGHTING_INCLUDE__

struct SurfaceOutputStandardSSSS
{
    half3 Albedo;
    // base (diffuse or specular) color
    half3 Normal;
    // tangent space normal, if written
    half3 Emission;
    half Metallic;
    // 0=non-metal, 1=metal
    // Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
    // Everywhere in the code you meet smoothness it is perceptual smoothness
    half Smoothness;
    // 0=rough, 1=smooth
    half Occlusion;
    // occlusion (default 1)
    half Alpha;
    // alpha for transparencies

    half4 SubSurfaceScatteringColorAndRadius;
    half Transmittance;
    bool Interleaved;
};

#endif