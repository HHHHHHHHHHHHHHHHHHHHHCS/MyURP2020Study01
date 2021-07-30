// #define DO_ANIMATE

#define DO_LIGHT_SAMPLING
#define DO_THREADED
// 46 spheres (2 emissive) when enabled; 9 spheres (1 emissive) when disabled
#define DO_BIG_SCENE

using System;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;
using static Unity.Mathematics.math;
using static MyGraphics.Scripts.CPURayTracing.CPURayTracingMathUtil;
using float3 = Unity.Mathematics.float3;

//copyby https://github.com/aras-p/ToyPathTracer/tree/b076563906169aa2f9e6d7218ef85decf81f8f72
namespace MyGraphics.Scripts.CPURayTracing
{
	public struct Material
	{
		public enum Type
		{
			Lambert,
			Metal,
			Dielectric
		}

		private static int GuidSpawn;

		public int guid;
		public Type type;
		public float3 albedo;
		public float3 emissive;
		public float roughness;
		public float ri;

		public Material(Type t, float3 a, float3 e, float r, float i)
			=> (guid, type, albedo, emissive, roughness, ri) = (GuidSpawn++, t, a, e, r, i);

		public bool HasEmission => emissive.x > 0 || emissive.y > 0 || emissive.z > 0;
	}

	public class CPURayTracing
	{
		private const int DO_SAMPLES_PER_PIXEL = 4;
		private const float DO_ANIMATE_SMOOTHING = 0.5f;

		private const float kMinT = 0.001f;
		private const float kMaxT = float.MaxValue; //1.0e7f;
		private const int kMaxDepth = 10;

		#region Data

		private static Sphere[] spheresData =
		{
			new Sphere(new float3(0, -100.5f, -1), 100),
			new Sphere(new float3(2, 0, -1), 0.5f),
			new Sphere(new float3(0, 0, -1), 0.5f),
			new Sphere(new float3(-2, 0, -1), 0.5f),
			new Sphere(new float3(2, 0, 1), 0.5f),
			new Sphere(new float3(0, 0, 1), 0.5f),
			new Sphere(new float3(-2, 0, 1), 0.5f),
			new Sphere(new float3(0.5f, 1, 0.5f), 0.5f),
			new Sphere(new float3(-1.5f, 1.5f, 0f), 0.3f),
#if DO_BIG_SCENE
			new Sphere(new float3(4, 0, -3), 0.5f),
			new Sphere(new float3(3, 0, -3), 0.5f),
			new Sphere(new float3(2, 0, -3), 0.5f),
			new Sphere(new float3(1, 0, -3), 0.5f),
			new Sphere(new float3(0, 0, -3), 0.5f),
			new Sphere(new float3(-1, 0, -3), 0.5f),
			new Sphere(new float3(-2, 0, -3), 0.5f),
			new Sphere(new float3(-3, 0, -3), 0.5f),
			new Sphere(new float3(-4, 0, -3), 0.5f),
			new Sphere(new float3(4, 0, -4), 0.5f),
			new Sphere(new float3(3, 0, -4), 0.5f),
			new Sphere(new float3(2, 0, -4), 0.5f),
			new Sphere(new float3(1, 0, -4), 0.5f),
			new Sphere(new float3(0, 0, -4), 0.5f),
			new Sphere(new float3(-1, 0, -4), 0.5f),
			new Sphere(new float3(-2, 0, -4), 0.5f),
			new Sphere(new float3(-3, 0, -4), 0.5f),
			new Sphere(new float3(-4, 0, -4), 0.5f),
			new Sphere(new float3(4, 0, -5), 0.5f),
			new Sphere(new float3(3, 0, -5), 0.5f),
			new Sphere(new float3(2, 0, -5), 0.5f),
			new Sphere(new float3(1, 0, -5), 0.5f),
			new Sphere(new float3(0, 0, -5), 0.5f),
			new Sphere(new float3(-1, 0, -5), 0.5f),
			new Sphere(new float3(-2, 0, -5), 0.5f),
			new Sphere(new float3(-3, 0, -5), 0.5f),
			new Sphere(new float3(-4, 0, -5), 0.5f),
			new Sphere(new float3(4, 0, -6), 0.5f),
			new Sphere(new float3(3, 0, -6), 0.5f),
			new Sphere(new float3(2, 0, -6), 0.5f),
			new Sphere(new float3(1, 0, -6), 0.5f),
			new Sphere(new float3(0, 0, -6), 0.5f),
			new Sphere(new float3(-1, 0, -6), 0.5f),
			new Sphere(new float3(-2, 0, -6), 0.5f),
			new Sphere(new float3(-3, 0, -6), 0.5f),
			new Sphere(new float3(-4, 0, -6), 0.5f),
			new Sphere(new float3(1.5f, 1.5f, -2), 0.3f),
#endif // #if DO_BIG_SCENE        
		};

		private static Material[] sphereMatsData =
		{
			new Material(Material.Type.Lambert, new float3(0.8f, 0.8f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.4f, 0.4f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.4f, 0.8f, 0.4f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.4f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.8f, 0.4f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.8f, 0.4f), new float3(0, 0, 0), 0.2f, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.8f, 0.4f), new float3(0, 0, 0), 0.6f, 0),
			new Material(Material.Type.Dielectric, new float3(0.4f, 0.4f, 0.4f), new float3(0, 0, 0), 0, 1.5f),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.6f, 0.2f), new float3(30, 25, 15), 0, 0),
#if DO_BIG_SCENE
			new Material(Material.Type.Lambert, new float3(0.1f, 0.1f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.2f, 0.2f, 0.2f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.3f, 0.3f, 0.3f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.4f, 0.4f, 0.4f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.5f, 0.5f, 0.5f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.6f, 0.6f, 0.6f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.7f, 0.7f, 0.7f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.8f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.9f, 0.9f, 0.9f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.1f, 0.1f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.2f, 0.2f, 0.2f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.3f, 0.3f, 0.3f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.4f, 0.4f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.5f, 0.5f, 0.5f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.6f, 0.6f, 0.6f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.7f, 0.7f, 0.7f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.8f, 0.8f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.9f, 0.9f, 0.9f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.8f, 0.1f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.8f, 0.5f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.8f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.4f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.1f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.1f, 0.8f, 0.5f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.1f, 0.8f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.1f, 0.1f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.5f, 0.1f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.1f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.5f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.8f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.4f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.1f, 0.8f, 0.1f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.1f, 0.8f, 0.5f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.1f, 0.8f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.1f, 0.1f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Metal, new float3(0.5f, 0.1f, 0.8f), new float3(0, 0, 0), 0, 0),
			new Material(Material.Type.Lambert, new float3(0.1f, 0.2f, 0.5f), new float3(3, 10, 20), 0, 0),
#endif
		};

		#endregion

		private SpheresSOA spheresSOA;

		public CPURayTracing()
		{
			spheresSOA = new SpheresSOA(spheresData.Length);
		}

		public void Dispose()
		{
			spheresSOA.Dispose();
		}

		private static bool HitWorld(Ray r, float tMin, float tMax
			, ref Hit outHit, ref int outID, ref SpheresSOA spheres)
		{
			outID = spheres.HitSpheres(ref r, tMin, tMax, ref outHit);
			return outID != -1;
		}

		private static bool Scatter(Material mat, Ray r_in, Hit rec, out float3 attenuation, out Ray scattered,
			out float3 outLightE, ref int inoutRayCount, ref SpheresSOA spheres, NativeArray<Material> materials,
			ref uint randState)
		{
			outLightE = new float3(0, 0, 0);
			if (mat.type == Material.Type.Lambert)
			{
				//随机在表面一个点发散
				float3 target = rec.pos + rec.normal + RandomUnitVector(ref randState);
				scattered = new Ray(rec.pos, normalize(target - rec.pos));
				attenuation = mat.albedo;

#if DO_LIGHT_SAMPLING
				for (int j = 0; j < spheres.emissiveCount; ++j)
				{
					int i = spheres.emissives[j];
					//if mat is self then skip
					//if(&mat == &smat)
					//	continue;//skip self
					if (mat.guid == materials[i].guid)
					{
						continue;
					}

					//var s = spheres[i];
					float3 sCenter = new float3(spheres.centerX[i], spheres.centerY[i], spheres.centerZ[i]);
					float sqRadius = spheres.sqRadius[i];

					float sqLen = lengthsq(rec.pos - sCenter);

					if (sqLen == 0)
					{
						continue;
					}

					//create a random direction towards sphere
					//coord system for sampling: sw,su,sv
					float3 sw = normalize(sCenter - rec.pos);
					float3 su = normalize(cross(abs(sw.x) > 0.01f ? new float3(0, 1, 0) : new float3(1, 0, 0), sw));
					float3 sv = cross(sw, su);
					//sample sphere by solid anglePI
					//发光球的半径越大或者两球距离过小  球越会朝向发光球  为了准确性
					float cosAMax = sqrt(max(0.0f, 1.0f - sqRadius / sqLen));
					float eps1 = RandomFloat01(ref randState);
					float eps2 = RandomFloat01(ref randState);
					float cosA = 1 - eps1 * (1 - cosAMax);
					float sinA = sqrt(1.0f - cosA * cosA);
					float phi = 2 * PI * eps2;
					//随机半球   rec球朝向自发光球
					float3 l = su * cos(phi) * sinA + sv * sin(phi) * sinA + sw * cosA;
					l = normalize(l);

					//shoot shadow ray
					Hit lightHit = default(Hit);
					int hitID = 0;
					inoutRayCount++;
					if (HitWorld(new Ray(rec.pos, l), kMinT, kMaxT, ref lightHit, ref hitID, ref spheres) && hitID == i)
					{
						//TODO:是否存在能量不守恒
						//如  E * 2*kPI*(1-0)/kPI => E*2  超出范围了
						//如  E * 2*kPI*(1-0.5)/kPI => E  一半角度的时候 已经满能量了
						float omega = 2 * PI * (1 - cosAMax);

						float3 rdir = r_in.dir;
						float3 nl = dot(rec.normal, rdir) < 0.0f ? rec.normal : -rec.normal;
						outLightE += (mat.albedo * materials[i].emissive) * (max(0.0f, dot(l, nl)) * omega / PI);
					}
				}
#endif
				return true;
			}
			else if (mat.type == Material.Type.Metal)
			{
				float3 refl = reflect(r_in.dir, rec.normal);
				scattered = new Ray(rec.pos, normalize(refl + mat.roughness * RandomInUnitSphere(ref randState)));
				attenuation = mat.albedo;
				return dot(scattered.dir, rec.normal) > 0;
			}
			else if (mat.type == Material.Type.Dielectric)
			{
				float3 outWN; //out world normal
				float3 rdir = r_in.dir;
				float3 refl = reflect(rdir, rec.normal);
				float nint;
				attenuation = new float3(1, 1, 1);
				float3 refr;
				float reflProb;
				float cosine;
				float dn = dot(rdir, rec.normal);
				//折射的  射入和射出
				if (dn > 0)
				{
					outWN = -rec.normal;
					nint = mat.ri;
					cosine = mat.ri * dn;
				}
				else
				{
					outWN = rec.normal;
					nint = 1.0f / mat.ri;
					cosine = -dn;
				}

				//如果折射射入成功  计算光滑度
				//reflProb越大则越粗糙    走反射概率越大
				//cosine越大  reflProb越小    ri越大  reflProb越大
				if (Refract(rdir, outWN, nint, out refr))
				{
					reflProb = Schlick(cosine, mat.ri);
				}
				else
				{
					reflProb = 1;
				}

				//越光滑  
				if (RandomFloat01(ref randState) < reflProb)
				{
					scattered = new Ray(rec.pos, normalize(refl));
				}
				else
				{
					scattered = new Ray(rec.pos, normalize(refr));
				}

				return true;
			}
			else
			{
				//Bug标记
				attenuation = new float3(1, 0, 1);
				scattered = default;
				return false;
			}

			return false;
		}


		private static float3 Trace(Ray r, int depth, ref int inoutRayCount, ref SpheresSOA spheres,
			NativeArray<Material> materials, ref uint randState, bool doMaterialE = true)
		{
			Hit rec = default;
			int id = 0;
			++inoutRayCount;
			if (HitWorld(r, kMinT, kMaxT, ref rec, ref id, ref spheres))
			{
				var mat = materials[id];
				var matE = mat.emissive;
				if (depth < kMaxDepth && Scatter(mat, r, rec, out float3 attenuation, out Ray scattered,
					out float3 lightE, ref inoutRayCount, ref spheres, materials, ref randState))
				{
#if DO_LIGHT_SAMPLING
					if (!doMaterialE)
					{
						matE = new float3(0, 0, 0);
					}

					doMaterialE = (mat.type != Material.Type.Lambert);
#endif
					if (all(attenuation == float3.zero))
					{
						return matE + lightE;
					}
					else
					{
						return matE + lightE + attenuation * Trace(scattered, depth + 1, ref inoutRayCount, ref spheres,
							materials, ref randState, doMaterialE);
					}
				}
				else
				{
					return matE;
				}
			}
			else
			{
				// sky
				float3 unitDir = r.dir;
				float t = 0.5f * (unitDir.y + 1.0f);
				return ((1.0f - t) * new float3(1.0f, 1.0f, 1.0f) + t * new float3(0.5f, 0.7f, 1.0f)) * 0.3f;
			}
		}

		[BurstCompile]
		private struct TraceRowJob : IJobParallelFor
		{
			public int screenWidth, screenHeight, frameCount;
			public Camera cam;

			[NativeDisableParallelForRestriction] public NativeArray<Color> backbuffer;
			[NativeDisableParallelForRestriction] public NativeArray<int> rayCounter;
			[NativeDisableParallelForRestriction] public SpheresSOA spheres;
			[NativeDisableParallelForRestriction] public NativeArray<Material> materials;

			public void Execute(int y)
			{
				int backbufferIdx = y * screenWidth;
				float invWidth = 1.0f / screenWidth;
				float invHeight = 1.0f / screenHeight;
				float lerpFac = ((float) frameCount / (frameCount + 1));
#if DO_ANIMATE
				lerpFac = saturate(lerpFac * DO_ANIMATE_SMOOTHING);
#endif
				uint state = (uint) (y * 9781 + frameCount * 6271) | 1;
				int rayCount = 0;
				for (int x = 0; x < screenWidth; ++x)
				{
					float3 col = new float3(0, 0, 0);
					for (int s = 0; s < DO_SAMPLES_PER_PIXEL; s++)
					{
						float u = (x + RandomFloat01(ref state)) * invWidth;
						float v = (y + RandomFloat01(ref state)) * invHeight;
						Ray r = cam.GetRay(u, v, ref state);
						col += Trace(r, 0, ref rayCount, ref spheres, materials, ref state);
					}

					col /= (float) DO_SAMPLES_PER_PIXEL;

					Color prev = backbuffer[backbufferIdx];
					col = new float3(prev.r, prev.g, prev.b) * lerpFac + col * (1 - lerpFac);
					backbuffer[backbufferIdx] = new Color(col.x, col.y, col.z, 1);
					backbufferIdx++;
				}

				//TODO: how to do atomics add?
				rayCounter[0] += rayCount;
			}
		}

		public void DoDraw(float time, int frameCount, int screenWidth, int screenHeight,
			NativeArray<Color> backbuffer, out int outRayCount)
		{
			int rayCount = 0;
#if DO_ANIMATE
			spheresData[1].center.y = cos(time) + 1.0f;
			spheresData[8].center.z = sin(time) * 0.3f;
#endif
			float3 lookFrom = new float3(0, 2, 3);
			float3 lookAt = new float3(0, 0, 0);
			float distToFocus = 3f;
			float aperture = 0.1f;
#if DO_BIG_SCENE
			aperture *= 0.2f;
#endif
			Camera cam = new Camera(lookFrom, lookAt, new float3(0, 1, 0), 60,
				(float) screenWidth / (float) screenHeight, aperture, distToFocus);

			spheresSOA.Update(spheresData, sphereMatsData);

			TraceRowJob job;
			job.screenWidth = screenWidth;
			job.screenHeight = screenHeight;
			job.frameCount = frameCount;
			job.backbuffer = backbuffer;
			job.cam = cam;
			job.rayCounter = new NativeArray<int>(1, Allocator.TempJob);
			job.spheres = spheresSOA;
			job.materials = new NativeArray<Material>(sphereMatsData, Allocator.TempJob);
#if DO_THREADED
			var fence = job.Schedule(screenHeight, 4);
			fence.Complete();
#else
			for (int y = 0; y < screenHeight; ++y)
			{
				job.Execute(y);
			}
#endif
			rayCount = job.rayCounter[0];
			job.rayCounter.Dispose();
			job.materials.Dispose();

			outRayCount = rayCount;
		}
	}
}