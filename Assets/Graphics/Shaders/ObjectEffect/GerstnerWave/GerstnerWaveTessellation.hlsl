// https://zhuanlan.zhihu.com/p/42550699
//https://zhuanlan.zhihu.com/p/359999755
//这里用了自动的曲面细分 hull和domain
//还可以手动添加点 geom
#ifndef  __GERSTNER_WAVE_TESSELLATION_INCLUDE__
#define __GERSTNER_WAVE_TESSELLATION_INCLUDE__




struct a2v
{
    float4 positionOS:POSITION;
    float2 uv: TEXCOORD0;
    float3 normal:NORMAL;
    float4 color:COLOR;
};

struct v2h
{
    float4 positionOS : INTERNALTESSPOS;
    float4 color: COLOR;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

v2h tessVert(a2v IN)
{
    v2h o;
    o.positionOS = IN.positionOS;
    o.color = IN.color;
    o.normal = IN.normal;
    o.uv = IN.uv;
    return o;
}

struct h2d
{
    float edge[3]: SV_TessFactor;
    float inside: SV_InsideTessFactor;
};

[domain("tri")]
[outputcontrolpoints(3)]
[outputtopology("triangle_cw")]
[partitioning("fractional_odd")]
[patchconstantfunc("hullFunc")]
v2h tessHull(InputPatch<v2h, 3> patch,
             uint id: SV_OutputControlPointID)
{
    return patch[id];
}

float TessellationEdgeFactor(float3 p0, float3 p1)
{
    #if defined(_TESSELLATION_EDGE)
    float edgeLength = distance(p0, p1);

    float3 edgeCenter = (p0 + p1) * 0.5;
    float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

    return edgeLength * _ScreenParams.y/ (_TessellationEdgeLength * viewDistance);
    #else
    return _TessellationUniform;
    #endif
}

h2d hullFunc(InputPatch<v2h, 3> patch)
{
    float3 p0 = mul(unity_ObjectToWorld, patch[0].positionOS).xyz;
    float3 p1 = mul(unity_ObjectToWorld, patch[1].positionOS).xyz;
    float3 p2 = mul(unity_ObjectToWorld, patch[2].positionOS).xyz;
    h2d f;
    f.edge[0] = TessellationEdgeFactor(p1, p2);
    f.edge[1] = TessellationEdgeFactor(p2, p0);
    f.edge[2] = TessellationEdgeFactor(p0, p1);
    f.inside =
    (TessellationEdgeFactor(p1, p2) +
        TessellationEdgeFactor(p2, p0) +
        TessellationEdgeFactor(p0, p1)) * (1 / 3.0);
    return f;
}

struct v2f
{
    float4 positionCS: SV_POSITION;
    float2 uv: TEXCOORD0;
    float3 normalWS: TEXCOORD1;
    float3 positionWS: TEXCOORD2;
    float3 tangentWS: TEXCOORD3;
    float4 scrPos: TEXCOORD4;
    float heightOS: TEXCOORD5;
    float fogFactor: TEXCOORD6;
};

v2f vert(a2v v);

[domain("tri")]
v2f tessDomain(h2d factors,
OutputPatch < v2h, 3 > patch,
float3 barycentricCoordinates: SV_DomainLocation)
{
    a2v data;
        
    #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
        patch[0].fieldName * barycentricCoordinates.x + \
        patch[1].fieldName * barycentricCoordinates.y + \
        patch[2].fieldName * barycentricCoordinates.z;
        
        
    MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS)
    MY_DOMAIN_PROGRAM_INTERPOLATE(color)
    MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
        
    return vert(data);
}

#endif
