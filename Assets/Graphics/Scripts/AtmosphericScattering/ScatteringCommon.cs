using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.AtmosphericScattering
{
	public enum LUTUpdateMode
	{
		OnStart,
		OnUpdate,
	}

	public enum DebugMode
	{
		None,
		Extinction,
		Inscattering,
	}

	public static class IDKeys
	{
		public const string csIntegrateCPDensity = "CSIntegrateCPDensity";
		public const string CSSunOnSurface = "CSSunOnSurface";
		public const string CSInScattering = "CSInScattering";
		public const string CSAmbient = "CSAmbient";

		public const string kDebugExtinction = "_DEBUG_EXTINCTION";
		public const string kDebugInscattering = "_DEBUG_INSCATTERING";
		public const string kAerialPerspective = "_AERIAL_PERSPECTIVE";//TODO:
		public const string kLightShaft = "_LIGHT_SHAFT";

		public static readonly int RWIntergalCPDensityLUT_ID = Shader.PropertyToID("_RWIntegralCPDensityLUT");
		public static readonly int IntergalCPDensityLUT_ID = Shader.PropertyToID("_IntegralCPDensityLUT");

		public static readonly int RWHemiSphereRandomNormlizedVecLUT_ID =
			Shader.PropertyToID("_RWHemiSphereRandomNormlizedVecLUT");

		public static readonly int RWAmbientLUT_ID = Shader.PropertyToID("_RWAmbientLUT");
		public static readonly int RWInScatteringLUT_ID = Shader.PropertyToID("_RWInScatteringLUT");
		public static readonly int InScatteringLUT_ID = Shader.PropertyToID("_InScatteringLUT");
		public static readonly int RWSunOnSurfaceLUT_ID = Shader.PropertyToID("_RWSunOnSurfaceLUT");

		public static readonly int DensityScaleHeight_ID = Shader.PropertyToID("_DensityScaleHeight");
		public static readonly int PlanetRadius_ID = Shader.PropertyToID("_PlanetRadius");
		public static readonly int AtmosphereHeight_ID = Shader.PropertyToID("_AtmosphereHeight");
		public static readonly int SurfaceHeight_ID = Shader.PropertyToID("_SurfaceHeight");
		public static readonly int DistanceScale_ID = Shader.PropertyToID("_DistanceScale");
		public static readonly int ScatteringR_ID = Shader.PropertyToID("_ScatteringR");
		public static readonly int ScatteringM_ID = Shader.PropertyToID("_ScatteringM");
		public static readonly int ExtinctionR_ID = Shader.PropertyToID("_ExtinctionR");
		public static readonly int ExtinctionM_ID = Shader.PropertyToID("_ExtinctionM");
		public static readonly int IncomingLight_ID = Shader.PropertyToID("_LightFromOuterSpace");
		public static readonly int SunIntensity_ID = Shader.PropertyToID("_SunIntensity");
		public static readonly int SunMieG_ID = Shader.PropertyToID("_SunMieG");
		public static readonly int MieG_ID = Shader.PropertyToID("_MieG");
		public static readonly int FrustumCorners_ID = Shader.PropertyToID("_FrustumCorners");
	}

	public static class Utils
	{
		public static void CheckOrCreateLUT(ref RenderTexture targetLUT, Vector2Int size, RenderTextureFormat format)
		{
			if (targetLUT == null || (targetLUT.width != size.x && targetLUT.height != size.y))
			{
				if (targetLUT != null)
				{
					targetLUT.Release();
				}

				var rt = new RenderTexture(size.x, size.y, 0, format, RenderTextureReadWrite.Linear);
				rt.useMipMap = false;
				rt.filterMode = FilterMode.Bilinear;
				rt.enableRandomWrite = true;
				rt.Create();
				targetLUT = rt;
			}
		}

		public static void ReadRTPixelsBackToCPU(RenderTexture src, Texture2D dst)
		{
			RenderTexture activeRT = RenderTexture.active;
			RenderTexture.active = src;
			dst.ReadPixels(new Rect(0, 0, dst.width, dst.height), 0, 0);
			RenderTexture.active = activeRT;
		}

		public static void Dispatch(ComputeShader cs, int kernel, Vector2Int lutSize)
		{
			if (cs == null)
			{
				Debug.LogError("Compute shader for precompute scattering lut is empty!");
				return;
			}

			cs.GetKernelThreadGroupSizes(kernel, out var threadNumX, out var threadNumY, out var threadNumZ);
			cs.Dispatch(kernel, lutSize.x / (int) threadNumX, lutSize.y / (int) threadNumY,
				1);
		}

		public static void HDRToColorIntensity(Color hdrColor, out Color color, out float intensity)
		{
			intensity = Mathf.Ceil(Mathf.Max(hdrColor.r, Mathf.Max(hdrColor.g, hdrColor.b)));
			color = hdrColor / intensity;
		}
	}
}