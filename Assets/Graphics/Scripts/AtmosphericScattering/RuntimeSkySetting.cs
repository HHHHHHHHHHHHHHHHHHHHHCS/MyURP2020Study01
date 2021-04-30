using System;
using UnityEngine;

namespace Graphics.Scripts.AtmosphericScattering
{
	//https://zhuanlan.zhihu.com/p/127026136
	//https://github.com/PZZZB/Atmospheric-Scattering-URP
	public class RuntimeSkySetting : MonoBehaviour
	{
		// Look up table update mode, it's better to use everyframe mode when you're in edit mode, need change params frequently.
		public LUTUpdateMode lutUpdateMode = LUTUpdateMode.OnUpdate;

		[Header("Environments")] public Light mainLight;

		[ColorUsage(false, true)] public Color lightFromOuterSpace = Color.white;

		public float planetRadius = 6357000.0f;
		public float atmosphereHeight = 12000f;
		public float surfaceHeight;

		[Header("Particles")] public float rDensityScale = 7994.0f;

		public float mDensityScale = 1200;

		[Header("Sun Disk")] public float sunIntensity = 0.75f;

		[Range(-1, 1)] public float sunMieG = 0.98f;

		[Header("Precomputation")] public ComputeShader computerShader;

		public Vector2Int integrateCPDensityLUTSize = new Vector2Int(512, 512);
		public Vector2Int sunOnSurfaceLUTSize = new Vector2Int(512, 512);
		public int ambientLUTSize = 512;
		public Vector2Int inScatteringLUTSize = new Vector2Int(1024, 1024);

		[Header("Debug/Output")] [NonSerialized]
		private bool m_ShowFrustumCorners = false;

		[NonSerialized] [ColorUsage(false, true)]
		private Color m_MainLightColor;

		[NonSerialized] [ColorUsage(false, true)]
		private Color m_AmbientColor;

		// x : dot(-mianLightDir,worldUp)，y：height
		[NonSerialized] private RenderTexture m_IntegrateCPDensityLUT;

		// x : dot(-mianLightDir,worldUp)，y：height
		[NonSerialized] private RenderTexture m_SunOnSurfaceLUT;

		// x : dot(-mianLightDir,worldUp)，y：height
		[NonSerialized] private RenderTexture m_AmbientLUT;

		[NonSerialized] private RenderTexture m_InScatteringLUT;

		private Texture2D m_SunOnSurfaceLUTReadToCPU;
		private Texture2D m_HemiSphereRandomNormlizedVecLUT;
		private Texture2D m_AmbientLUTReadToCPU;

		private Camera m_Camera;
		private Vector3[] m_FrustumCorners = new Vector3[4];
		private Vector4[] m_FrustumCornersVec4 = new Vector4[4];
	}
}