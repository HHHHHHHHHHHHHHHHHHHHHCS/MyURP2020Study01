//#define DO_ANIMATE
#define DO_LIGHT_SAMPLING
#define DO_THREADED
// 46 spheres (2 emissive) when enabled; 9 spheres (1 emissive) when disabled
#define DO_BIG_SCENE

using Unity.Mathematics;

namespace Graphics.Scripts.CPURayTracing
{
	public struct Material
	{
		public enum Type
		{
			Lambert,
			Metal,
			Dielectric
		};

		public Type type;
		public float3 albedo;
		public float3 emissive;
		public float roughness;
		public float ri;

		public Material(Type t, float3 a, float3 e, float r, float i)
			=> (type, albedo, emissive, roughness, ri) = (t, a, e, r, i);

		public bool HasEmission => emissive.x > 0 || emissive.y > 0 || emissive.z > 0;
	}

	public class CPURayTracing
	{
	}
}