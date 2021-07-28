using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Mathematics;
using static Unity.Mathematics.math;

namespace MyGraphics.Scripts.CPURayTracing
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

	public struct SpheresSOA
	{
		[ReadOnly] public NativeArray<float> centerX;
		[ReadOnly] public NativeArray<float> centerY;
		[ReadOnly] public NativeArray<float> centerZ;
		[ReadOnly] public NativeArray<float> sqRadius;
		[ReadOnly] public NativeArray<float> invRadius;
		[ReadOnly] public NativeArray<int> emissives;
		public int emissiveCount;

		public SpheresSOA(int len)
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
				centerX[i] = centerY[i] = centerZ[i] = float.MaxValue;
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
				float4 nb = coX * rDirX + coY * rDirY + coZ * rDirZ;
				float4 c = coX * coX + coY * coY + coZ * coZ - sSqRadius;
				float4 discr = nb * nb - c;
				bool4 discrPos = discr > 0.0f; //如果有一个交点,不算碰撞成功
				//if ray hits any of the 4 spheres
				if (any(discrPos))
				{
					float4 discrSq = sqrt(discr);

					//rau could hit spheres at t0&t1
					float4 t0 = nb - discrSq;
					float4 t1 = nb + discrSq;

					// if t0 is above min, take it (since it's the earlier hit); else try t1.
					//如果t0>tmin4 那就试一试t1  如果t1还不行  mask也是失败
					float4 t = select(t1, t0, t0 > tMin4);
					bool4 mask = discrPos & (t > tMin4) & (t < hitT) & (sCenterX < float.MaxValue);
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
				int laneMask = csum(int4(hitT == float4(minT)) * int4(1, 2, 4, 8));
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
		//aperture焦聚 聚焦虚焦用   focusDist是near distance
		public Camera(float3 lookFrom, float3 lookAt, float3 vup, float vfov, float aspect, float aperture,
			float focusDist)
		{
			lensRadius = aperture / 2;
			float theta = vfov * PI / 180;
			float halfHeight = tan(theta / 2);
			float halfWidth = aspect * halfHeight;
			origin = lookFrom;
			w = normalize(lookFrom - lookAt);
			u = normalize(cross(vup, w));
			v = cross(w, u);
			lowerLeftCorner = origin - focusDist * (halfWidth * u + halfHeight * v + w);

			horizontal = 2 * halfWidth * focusDist * u;
			vertical = 2 * halfHeight * focusDist * v;
		}

		public Ray GetRay(float s, float t, ref uint state)
		{
			float3 rd = lensRadius * CPURayTracingMathUtil.RandomInUnitDisk(ref state);
			float3 offset = u * rd.x + v * rd.y;
			return new Ray(origin + offset,
				normalize(lowerLeftCorner + s * horizontal + t * vertical - origin - offset));
		}
	}


	public static class CPURayTracingMathUtil
	{
		//Math
		//----------------------------

		public static bool Refract(float3 v, float3 n, float nint, out float3 outRefracted)
		{
			float dt = dot(v, n);
			float discr = 1.0f - nint * nint * (1 - dt * dt);
			if (discr > 0)
			{
				outRefracted = nint * (v - n * dt) - n * sqrt(discr);
				return true;
			}

			outRefracted = new float3(0, 0, 0);
			return false;
		}

		// cosine越大  reflProb越小    ri越大  reflProb越大
		public static float Schlick(float cosine, float ri)
		{
			float r0 = (1 - ri) / (1 + ri);
			r0 = r0 * r0;
			return r0 + (1 - r0) * pow(1 - cosine, 5);
		}


		//Random
		//-------------------

		//生成随机数
		private static uint XorShift32(ref uint state)
		{
			uint x = state;
			x ^= x << 13;
			x ^= x >> 17;
			x ^= x << 15;
			state = x;
			return x;
		}

		//[0,1)
		public static float RandomFloat01(ref uint state)
		{
			// 0xFFFFFF => 16777215
			return (XorShift32(ref state) & 0xFFFFFF) / 16777216.0f;
		}

		public static float3 RandomInUnitDisk(ref uint state)
		{
			float3 p;
			// do
			// {
			// 	p = 2.0f * new float3(RandomFloat01(ref state), RandomFloat01(ref state), 0) - new float3(1, 1, 0);
			// } while (lengthsq(p) >= 1.0);
			// return p;

			var x = RandomFloat01(ref state);
			var y = RandomFloat01(ref state);

			float length = 1;
			float dx, dy;
			if (x == 0 && y == 0)
			{
				// return float3(2, 2, 0); // => float3(1,1,0)+float3(1,1,0);
				dx = 1;
				dy = 1;
			}
			else
			{
				float len = sqrt(x * x + y * y);
				dx = x / len;
				dy = y / len;

				if (x != 0 && y != 0)
				{
					float maxDis = min(y / x, x / y); //碰触到 x=1|y=1 的点的距离
					maxDis = sqrt(maxDis * maxDis + 1 * 1) - 1;
					length += maxDis * RandomFloat01(ref state);
				}
			}


			//象限
			var xx = RandomFloat01(ref state);
			if (xx < 0.25f) //第一象限
			{
			}
			else if (xx < 0.5f) //第二象限
			{
				dx *= -1;
			}
			else if (xx < 0.75f) //第三象限
			{
				dx *= -1;
				dy *= -1;
			}
			else //if (xx < 1f)//第四象限
			{
				dy *= -1;
			}

			p = float3(dx * length, dy * length, 0);


			return p;
		}

		public static float3 RandomInUnitSphere(ref uint state)
		{
			float3 p;
			// do
			// {
			// 	p = 2.0f * new float3(RandomFloat01(ref state), RandomFloat01(ref state), RandomFloat01(ref state)) -
			// 	    new float3(1, 1, 1);
			// } while (lengthsq(p) >= 1.0);
			// return p;

			var x = RandomFloat01(ref state);
			var y = RandomFloat01(ref state);
			var z = RandomFloat01(ref state);

			float length = 1;
			float dx, dy, dz;

			if (x == 0 && y == 0 && z == 0)
			{
				// return float3(2, 2, 2); // => float3(1,1,1)+float3(1,1,1);
				dx = 1;
				dy = 1;
				dz = 1;
			}
			else
			{
				float len = sqrt(x * x + y * y + z * z);
				dx = x / len;
				dy = y / len;
				dz = z / len;

				float a, b, c;
				float macD = max(max(x, y), z);
				a = x / macD;
				b = y / macD;
				c = z / macD;

				float maxDis = sqrt(a * a + b * b + c * c) - 1;
				length += maxDis * RandomFloat01(ref state);
			}


			//象限
			var xx = RandomFloat01(ref state);
			if (xx < 0.125f) //第一象限
			{
			}
			else if (xx < 0.25f) //第二象限
			{
				dx *= -1;
			}
			else if (xx < 0.375f) //第三象限
			{
				dx *= -1;
				dy *= -1;
			}
			else if (xx < 0.5f) //第四象限
			{
				dy *= -1;
			}

			if (xx < 0.625f) //第五象限
			{
				dz *= -1;
			}
			else if (xx < 0.75f) //第六象限
			{
				dx *= -1;
				dz *= -1;
			}
			else if (xx < 0.875f) //第七象限
			{
				dx *= -1;
				dy *= -1;
				dz *= -1;
			}
			else //if (xx < 1f)//第八象限
			{
				dy *= -1;
				dz *= -1;
			}

			p = float3(dx * length, dy * length, dz * length);


			return p;
		}

		public static float3 RandomUnitVector(ref uint state)
		{
			float z = RandomFloat01(ref state) * 2.0f - 1.0f;
			float a = RandomFloat01(ref state) * 2.0f * PI;
			float r = sqrt(1.0f - z * z);
			float x, y;
			sincos(a, out x, out y);
			return new float3(r * x, r * y, z);
		}
	}
}