#ifndef __RAY_TRACING_GEM__
#define __RAY_TRACING_GEM__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float _IOR;
int _TraceCount;

float3 _Color;
float _AbsorbIntensity;
float _ColorAdd;
float _ColorMultiply;

float _Specular;

//Mesh
//-----------------

struct MeshObject
{
    float4x4 localToWorldMatrix;
    int indicesOffset;
    int indicesCount;
};

int _MeshIndex;

StructuredBuffer<MeshObject> _MeshObjects;
StructuredBuffer<float3> _Vertices;
StructuredBuffer<int> _Indices;

//Ray
//----------------------

struct Ray
{
    float3 origin;
    float3 direction;
    float3 energy;
    float absorbDistance;
};

Ray CreateRay(float3 origin, float3 direction)
{
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    ray.energy = float3(1.0f, 1.0f, 1.0f);
    ray.absorbDistance = 0;
    return ray;
}

Ray CreateCameraRay(float2 uv)
{
    // Transform the camera origin to world space
    float3 origin = mul(UNITY_MATRIX_I_V, float4(0.0f, 0.0f, 0.0f, 1.0f)).xyz;
    float4 _direction = mul(UNITY_MATRIX_I_VP, float4(uv, 0.0f, 1.0f));
    float3 direction = normalize(_direction.xyz / _direction.w);

    return CreateRay(origin, direction);
}

//Ray Hit
//-----------------------

struct RayHit
{
    float3 position;
    float distance;
    float3 normal;
};

RayHit CreateRayHit()
{
    RayHit hit;
    hit.position = float3(0.0f, 0.0f, 0.0f);
    //1.#INF 也是 无穷大
    hit.distance = FLT_INF; //1.#INF;
    hit.normal = float3(0.0f, 0.0f, 0.0f);
    return hit;
}

//http://www.graphics.cornell.edu/pubs/1997/MT97.pdf
bool IntersectTriangle_MT97_NoCull(Ray ray, float3 vert0, float3 vert1, float3 vert2,
                                   inout float t, inout float u, inout float v)
{
    // find vectors for two edges sharing vert0
    float3 edge1 = vert1 - vert0;
    float3 edge2 = vert2 - vert0;

    // begin calculating determinant - also used to calculate U parameter
    float3 pvec = cross(ray.direction, edge2);

    // if determinant is near zero, ray lies in plane of triangle
    float det = dot(edge1, pvec);

    // use no culling
    // 面 和 射线平行  则失败
    if (det > -HALF_EPS && det < HALF_EPS)
    {
        return false;
    }
    float inv_det = 1.0 / det;

    float3 tvec = ray.origin - vert0;

    u = dot(tvec, pvec) * inv_det;
    if (u < 0.0 || u > 1.0)
    {
        return false;
    }

    //prepare to test v parameter
    float3 qvec = cross(tvec, edge1);

    v = dot(ray.direction, qvec) * inv_det;
    if (v < 0.0 || u + v > 1.0)
    {
        return false;
    }

    // calculate t, ray intersects triangle
    t = dot(edge2, qvec) * inv_det;

    return true;
}

void IntersectMeshObject(Ray ray,inout RayHit baseHit,MeshObject meshObject)
{
    // uint offset = meshObject.indicesOffset;
    //TODO:
}

#endif
