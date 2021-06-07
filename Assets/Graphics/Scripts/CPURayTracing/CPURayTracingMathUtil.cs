using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Mathematics;
using UnityEngine;
using static Unity.Mathematics.math;

namespace Graphics.Scripts.CPURayTracing
{
	public struct Ray
	{
		public float3 ori;
		public float3 dir;

		public Ray(float3 o, float3 d)
			=> (ori, dir) = (o, d);

		public float3 PointAt(float t) => ori + dir * t;
	}

	public struct Hit
	{
		public float3 pos;
		public float3 normal;
		public float t;
	}

	public struct Sphere
	{
		public float3 center;
		public float radius;

		public Sphere(float3 c, float r)
			=> (center, radius) = (c, r);
	}

	public struct SphereSOA
	{
		[ReadOnly] public NativeArray<float> centerX;
		[ReadOnly] public NativeArray<float> centerY;
		[ReadOnly] public NativeArray<float> centerZ;
		[ReadOnly] public NativeArray<float> sqRadius;
		[ReadOnly] public NativeArray<float> invRadius;
		[ReadOnly] public NativeArray<int> emissives;
		public int emissiveCount;

		public SphereSOA(int len)
		{
			var simdLen = ((len + 3) / 4) * 4;
			centerX = new NativeArray<float>(simdLen, Allocator.Persistent);
			centerY = new NativeArray<float>(simdLen, Allocator.Persistent);
			centerZ = new NativeArray<float>(simdLen, Allocator.Persistent);
			sqRadius = new NativeArray<float>(simdLen, Allocator.Persistent);
			invRadius = new NativeArray<float>(simdLen, Allocator.Persistent);
			// set trailing data to "impossible sphere" state
			for (int i = len; i < simdLen; ++i)
			{
				centerX[i] = centerY[i] = centerZ[i] = 10000.0f;
				sqRadius[i] = 0.0f;
				invRadius[i] = 0.0f;
			}

			emissives = new NativeArray<int>(simdLen, Allocator.Persistent);
			emissiveCount = 0;
		}

		public void Dispose()
		{
			centerX.Dispose();
			centerY.Dispose();
			centerZ.Dispose();
			sqRadius.Dispose();
			invRadius.Dispose();
			emissives.Dispose();
		}

		public void Update(Sphere[] src, Material[] mat)
		{
			emissiveCount = 0;
			for (var i = 0; i < src.Length; i++)
			{
				ref Sphere s = ref src[i];
				centerX[i] = s.center.x;
				centerY[i] = s.center.y;
				centerZ[i] = s.center.z;
				sqRadius[i] = s.radius * s.radius;
				invRadius[i] = 1.0f / s.radius;
				if (mat[i].HasEmission)
				{
					emissives[emissiveCount++] = i;
				}
			}
		}

		public unsafe int HitSpheres(ref Ray r, float tMin, float tMax, ref Hit outHit)
		{
			float4 hitT = tMax;
			int4 id = -1;
			float4 rOriX = r.ori.x;
			float4 rOriY = r.ori.y;
			float4 rOriZ = r.ori.z;
			float4 rDirX = r.dir.x;
			float4 rDirY = r.dir.y;
			float4 rDirZ = r.dir.z;
			float4 tMin4 = tMin;
			int4 curId = new int4(0, 1, 2, 3);
			int simdLen = centerX.Length / 4;
			//获取一个float4指针
			float4* ptrCenterX = (float4*) centerX.GetUnsafeReadOnlyPtr();
			float4* ptrCenterY = (float4*) centerY.GetUnsafeReadOnlyPtr();
			float4* ptrCenterZ = (float4*) centerZ.GetUnsafeReadOnlyPtr();
			float4* ptrSqRadius = (float4*) sqRadius.GetUnsafeReadOnlyPtr();
			for (int i = 0; i < simdLen; ++i)
			{
				float4 sCenterX = *ptrCenterX;
				float4 sCenterY = *ptrCenterY;
				float4 sCenterZ = *ptrCenterZ;
				float4 sSqRadius = *ptrSqRadius;
				float4 coX = sCenterX - rOriX;
				float4 coY = sCenterY - rOriY;
				float4 coZ = sCenterZ - rOriZ;
				float4 nb = coX * rDirX + coY * rDirY + coZ * rDirZ.z;
				float4 c = coX * coX + coY * coY + coZ * coZ - sSqRadius;
				float4 discr = nb * nb - c;
				bool4 discrPos = discr > 0.0f;
				//if ray hits any of the 4 spheres
				if (any(discrPos))
				{
					float4 discrSq = math.sqrt(discr);

					//rau could hit spheres at t0&t1
					float4 t0 = nb - discrSq;
					float4 t1 = nb + discrSq;

					// if t0 is above min, take it (since it's the earlier hit); else try t1.
					float4 t = select(t1, t0, t0 > tMin4);
					bool4 mask = discrPos & (t > tMin4) & (t < hitT);
					//if hit ,take it
					id = select(id, curId, mask);
					hitT = select(hitT, t, mask);
				}

				curId += int4(4);
				ptrCenterX++;
				ptrCenterY++;
				ptrCenterZ++;
				ptrSqRadius++;
			}

			// now we have up to 4 hits, find and return closest one
			float2 minT2 = min(hitT.xy, hitT.zw);
			float minT = min(minT2.x, minT2.y);
			if (minT < tMax)
			{
				int laneMask = csum(int4(hitT == float4(minT) * int4(1, 2, 4, 8)));
				//get index of first closet lane
				//tzcnt:返回二进制 末尾零的个数
				int lane = tzcnt(laneMask);
				// if (lane < 0 || lane > 3) Debug.LogError($"invalid lane {lane}");
				int hitId = id[lane];
				//if (hitId < 0 || hitId >= centerX.Length) Debug.LogError($"invalid hitID {hitId}");
				float finalHitT = hitT[lane];
				outHit.pos = r.PointAt(finalHitT);
				outHit.normal = (outHit.pos - float3(centerX[hitId], centerY[hitId], centerZ[hitId])) *
				                invRadius[hitId];
				outHit.t = finalHitT;
				return hitId;
			}

			return -1;
		}
	}


	public struct Camera
	{
		private float3 origin;
		private float3 lowerLeftCorner;
		private float3 horizontal;
		private float3 vertical;
		private float3 u, v, w;
		private float lensRadius;
		
		// vfov is top to bottom in degrees
		public Camera(float3 lookFrom, float3 lookAt, float3 vup, float vfov, float aspect, float aperture,
			float focusDist)
		{
			lensRadius = aperture / 2;
			float theta = vfov * CPURayTracingMathUtil.kPI / 180;
			float halfHeight = tan(theta / 2);
			float halfWidth = aspect * halfHeight;
			origin = lookFrom;
			w = normalize(lookFrom - lookAt);
			u = normalize(cross(vup, w));
			v = cross(w, u);
			lowerLeftCorner = origin - halfWidth * focusDist * u - halfHeight * focusDist * v - focusDist * w;
			
			//TODO:暂时还不知道 focusDist干嘛的
			horizontal = 2 * halfWidth * focusDist * u;
			vertical = 2 * halfHeight * focusDist * v;
		}

		public Ray GetRay(float s, float t, ref uint state)
		{
			//todo:
			// float3 rd = lensRadius * CPURayTracingMathUtil.RandomInUnitDisk(ref state);
			// float3 offset = u * rd.x + v * rd.y;
			// return new Ray(origin + offset,
			// 	normalize(lowerLeftCorner + s * horizontal + t * vertical - origin - offset));
		}


	}


	public class CPURayTracingMathUtil
	{
		public static float kPI => 3.1415926f;
	}
}