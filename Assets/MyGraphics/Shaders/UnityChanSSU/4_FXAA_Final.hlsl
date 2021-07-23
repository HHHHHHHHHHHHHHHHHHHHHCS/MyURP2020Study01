#ifndef __4_FXAA_FINAL__
#define __4_FXAA_FINAL__

#include "4_PostProcessCommon_Final.hlsl"

#define FXAA_SPAN_MAX           (8.0)
#define FXAA_REDUCE_MUL         (1.0 / 8.0)
#define FXAA_REDUCE_MIN         (1.0 / 128.0)

half3 Fetch(float2 coords, float2 offset)
{
    float2 uv = coords + offset;
    return SAMPLE_TEXTURE2D_X(_SrcTex, sampler_Linear_Clamp, uv).xyz;
}

half3 Load(int2 icoords, int idx, int idy)
{
    #if SHADER_API_GLES
    float2 uv = (icoords + int2(idx, idy)) * _SrcTex_TexelSize.zw;
    return SAMPLE_TEXTURE2D_X(_SourceTex, sampler_Linear_Clamp, uv).xyz;
    #else
    return LOAD_TEXTURE2D_X(_SrcTex, clamp(icoords + int2(idx, idy), 0, _SrcTex_TexelSize.zw - 1.0)).xyz;
    #endif
}

half3 FXAA(half3 color, float2 uv, int2 pos)
{
    half3 rgbNW = Load(pos, -1, -1);
    half3 rgbNE = Load(pos, 1, -1);
    half3 rgbSW = Load(pos, -1, 1);
    half3 rgbSE = Load(pos, 1, 1);

    rgbNW = saturate(rgbNW);
    rgbNE = saturate(rgbNE);
    rgbSW = saturate(rgbSW);
    rgbSE = saturate(rgbSE);

    half lumaNW = Luminance(rgbNW);
    half lumaNE = Luminance(rgbNE);
    half lumaSW = Luminance(rgbSW);
    half lumaSE = Luminance(rgbSE);
    half lumaM = Luminance(color);

    float2 dir;
    dir.x = ((lumaSW + lumaSE) - (lumaNW + lumaNE));
    dir.y = ((lumaNW + lumaSW) - (lumaNE + lumaSE));

    half lumaSum = lumaNW + lumaNE + lumaSW + lumaSE;
    float dirReduce = max(lumaSum * (0.25 * FXAA_REDUCE_MUL),FXAA_REDUCE_MIN);
    float rcpDirMin = rcp(min(abs(dir.x), abs(dir.y)) + dirReduce);

    dir = min((FXAA_SPAN_MAX).xx, max((-FXAA_SPAN_MAX).xx, dir * rcpDirMin)) * _SrcTex_TexelSize.xy;

    // Blur
    half3 rgb03 = Fetch(uv, dir * (0.0 / 3.0 - 0.5));
    half3 rgb13 = Fetch(uv, dir * (1.0 / 3.0 - 0.5));
    half3 rgb23 = Fetch(uv, dir * (2.0 / 3.0 - 0.5));
    half3 rgb33 = Fetch(uv, dir * (3.0 / 3.0 - 0.5));

    rgb03 = saturate(rgb03);
    rgb13 = saturate(rgb13);
    rgb23 = saturate(rgb23);
    rgb33 = saturate(rgb33);

    half3 rgbA = 0.5 * (rgb13 + rgb23);
    half3 rgbB = rgbA * 0.5 + 0.25 * (rgb03 + rgb33);

    half lumaB = Luminance(rgbB);

    half lumaMin = Min3(lumaM, lumaNW, Min3(lumaNE, lumaSW, lumaSE));
    half lumaMax = Max3(lumaM, lumaNW, Max3(lumaNE, lumaSW, lumaSE));

    color = ((lumaB < lumaMin) || (lumaB > lumaMax)) ? rgbA : rgbB;

    return color;
}

#endif
