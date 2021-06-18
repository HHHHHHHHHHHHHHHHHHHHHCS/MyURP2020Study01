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

void IntersectMeshObject(Ray ray, inout RayHit bestHit, MeshObject meshObject)
{
    uint offset = meshObject.indicesOffset;
    uint count = offset + meshObject.indicesCount;

    for (uint i = offset; i < count; i += 3)
    {
        float3 v0 = mul(meshObject.localToWorldMatrix, float4(_Vertices[_Indices[i]], 1)).xyz;
        float3 v1 = mul(meshObject.localToWorldMatrix, float4(_Vertices[_Indices[i + 1]], 1)).xyz;
        float3 v2 = mul(meshObject.localToWorldMatrix, float4(_Vertices[_Indices[i + 2]], 1)).xyz;

        float t, u, v;
        if (IntersectTriangle_MT97_NoCull(ray, v0, v1, v2, t, u, v))
        {
            if (t > 0 && t < bestHit.distance)
            {
                bestHit.distance = t;
                bestHit.position = ray.origin + t * ray.direction;
                bestHit.normal = normalize(cross(v1 - v0, v2 - v0));
            }
        }
    }
}

//Trace
//-----------------------

RayHit Trace(Ray ray)
{
    RayHit bestHit = CreateRayHit();

    //Trace mesh objects
    IntersectMeshObject(ray, bestHit, _MeshObjects[_MeshIndex]);

    return bestHit;
}

//Shade
//----------------------

half3 SampleCubemap(float3 direction)
{
    return SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, direction, 0).rgb;
}

float Refract(float3 i, float n, float eta, inout float3 o)
{
    float cosi = dot(-i, n);
    float cost2 = max(1.0f - eta * eta * (1 - cosi * cosi), 0);

    o = eta * i + ((eta * cosi - sqrt(cost2)) * n);
    return 1 - step(cost2,HALF_EPS);
}

float FresnelSchlick(float3 normal, float3 incident, float ref_idx)
{
    float cosine = dot(-incident, normal);
    float r0 = (1 - ref_idx) / (1 + ref_idx); //ref_idx = n2/n1
    r0 = r0 * r0;
    float ret = r0 + (1 - r0) * pow((1 - cosine), 5);
    return ret;
}

half3 Shade(inout Ray ray, RayHit hit, int depth)
{
    //1.#INF
    if (hit.distance < FLT_INF && depth < (_TraceCount - 1))
    {
        float3 specular = float3(0, 0, 0);

        float eta;
        float3 normal;

        //out
        if (dot(ray.direction, hit.normal) > 0)
        {
            normal = -hit.normal;
            eta = _IOR;
        }
        else //in
        {
            normal = hit.normal;
            eta = 1.0 / _IOR;
        }

        ray.origin = hit.position - normal * 0.001f;

        float3 refractRay;
        float refracted = Refract(ray.direction, normal, eta, refractRay);

        if (depth == 0.0)
        {
            float3 reflectDir = reflect(ray.direction, hit.normal);
            reflectDir = normalize(reflectDir);

            float3 reflectProb = FresnelSchlick(normal, ray.direction, eta) * _Specular;
            specular = SampleCubemap(reflectDir) * reflectProb;
            ray.energy *= 1 - reflectProb;
        }
        else
        {
            ray.absorbDistance += hit.distance;
        }

        //Refraction
        if (refracted == 1.0)
        {
            ray.direction = refractRay;
        }
        else //Total Internal Reflection
        {
            ray.direction = reflect(ray.direction, normal);
        }

        ray.direction = normalize(ray.direction);

        return specular;
    }
    else
    {
        ray.energy = 0.0f;

        float3 cubeColor = SampleCubemap(ray.direction);
        float3 absorbColor = 1.0 - _Color;
        float3 absorb = exp(-absorbColor * ray.absorbDistance * _AbsorbIntensity);

        return cubeColor * absorb * _ColorMultiply + _ColorAdd * _Color;
    }
}

half3 RayTrace(float2 screenUV)
{
    Ray ray = CreateCameraRay(screenUV);
    
    float3 result = 0;

    // UNITY_UNROLLX(10)
    for (int i = 0; i < _TraceCount; i++)
    {
        RayHit hit = Trace(ray);

        result += ray.energy * Shade(ray, hit, i);

        if (!any(ray.energy))
        {
            break;
        }
    }

    return result;
}


#endif
