#ifndef __4_POST_PROCESS_COMMON_FINAL__
#define __4_POST_PROCESS_COMMON_FINAL__

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#define EPSILON         1.0e-4

struct a2v
{
    uint vertexID :SV_VertexID;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
};

TEXTURE2D(_SrcTex);
SAMPLER(sampler_SrcTex);
float4 _SrcTex_TexelSize;

SAMPLER(sampler_Linear_Clamp);
SAMPLER(sampler_Point_Clamp);

v2f VertDefault(a2v IN)
{
    v2f o;
    o.vertex = GetFullScreenTriangleVertexPosition(IN.vertexID);
    o.uv = GetFullScreenTriangleTexCoord(IN.vertexID);
    return o;
}

half4 SafeHDR(half4 c)
{
    return min(c, HALF_MAX);
}

#if defined(UNITY_SINGLE_PASS_STEREO)
	float4 UnityStereoAdjustedTexelSize(float4 texelSize) // Should take in _MainTex_TexelSize
	{
		texelSize.x = texelSize.x * 2.0; // texelSize.x = 1/w. For a double-wide texture, the true resolution is given by 2/w. 
		texelSize.z = texelSize.z * 0.5; // texelSize.z = w. For a double-wide texture, the true size of the eye texture is given by w/2. 
		return texelSize;
	}
#else

float4 UnityStereoAdjustedTexelSize(float4 texelSize)
{
    return texelSize;
}
#endif

// Better, temporally stable box filtering
// [Jimenez14] http://goo.gl/eomGso
// . . . . . . .
// . A . B . C .
// . . D . E . .
// . F . G . H .
// . . I . J . .
// . K . L . M .
// . . . . . . .
half4 DownsampleBox13Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
{
    // UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, -1.0))

    half4 A = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, -1.0)));
    half4 B = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.0, -1.0)));
    half4 C = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, -1.0)));
    half4 D = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-0.5, -0.5)));
    half4 E = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.5, -0.5)));
    half4 F = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, 0.0)));
    half4 G = SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv ));
    half4 H = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, 0.0)));
    half4 I = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-0.5, 0.5)));
    half4 J = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.5, 0.5)));
    half4 K = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2(-1.0, 1.0)));
    half4 L = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 0.0, 1.0)));
    half4 M = SAMPLE_TEXTURE2D(tex, samplerTex,
                               UnityStereoTransformScreenSpaceTex(uv + texelSize * float2( 1.0, 1.0)));

    half2 div = (1.0 / 4.0) * half2(0.5, 0.125);

    half4 o = (D + E + I + J) * div.x;
    o += (A + B + G + F) * div.y;
    o += (B + C + H + G) * div.y;
    o += (F + G + L + K) * div.y;
    o += (G + H + M + L) * div.y;

    return o;
}

// Standard box filtering
half4 DownsampleBox4Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
{
    float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

    half4 s;
    s = (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)));

    return s * (1.0 / 4.0);
}


// 9-tap bilinear upsampler (tent filter)
half4 UpsampleTent(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
{
    //UnityStereoTransformScreenSpaceTex(uv - d.xy)

    float4 d = texelSize.xyxy * float4(1.0, 1.0, -1.0, 0.0) * sampleScale;

    half4 s;
    s = SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.xy));
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.wy)) * 2.0;
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv - d.zy));

    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)) * 2.0;
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv )) * 4.0;
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)) * 2.0;

    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy));
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.wy)) * 2.0;
    s += SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy));

    return s * (1.0 / 16.0);
}

// Standard box filtering
half4 UpsampleBox(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
{
    float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0) * (sampleScale * 0.5);

    half4 s;
    s = (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xy)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zy)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.xw)));
    s += (SAMPLE_TEXTURE2D(tex, samplerTex, UnityStereoTransformScreenSpaceTex(uv + d.zw)));

    return s * (1.0 / 4.0);
}

#endif
