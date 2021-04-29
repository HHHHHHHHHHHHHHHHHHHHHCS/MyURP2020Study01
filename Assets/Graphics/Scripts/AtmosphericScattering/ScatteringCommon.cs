using UnityEngine;

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
		public const string kDebugExtinction = "_DEBUG_EXTINCTION";
		public const string kDebugInscattering = "_DEBUG_INSCATTERING";
		public const string kAerialPerspective = "_AERIAL_PERSPECTIVE";
		public const string kLightShaft = "_LIGHT_SHAFT";
		
		public static readonly int RWintergalCPDensityLUT_ID = Shader.PropertyToID("_RWintegralCPDensityLUT");
        public static readonly int IntergalCPDensityLUT_ID = Shader.PropertyToID("_IntegralCPDensityLUT");
        public static readonly int RWhemiSphereRandomNormlizedVecLUT_ID = Shader.PropertyToID("_RWhemiSphereRandomNormlizedVecLUT");
        public static readonly int RWambientLUT_ID = Shader.PropertyToID("_RWambientLUT");
        public static readonly int RWinScatteringLUT_ID = Shader.PropertyToID("_RWinScatteringLUT");
        public static readonly int InScatteringLUT_ID = Shader.PropertyToID("_InScatteringLUT");
        public static readonly int RWsunOnSurfaceLUT_ID = Shader.PropertyToID("_RWsunOnSurfaceLUT");
        
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
}
