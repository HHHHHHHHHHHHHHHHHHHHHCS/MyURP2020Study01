using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.AtmosphericScattering
{
	//https://zhuanlan.zhihu.com/p/127026136
	//https://github.com/PZZZB/Atmospheric-Scattering-
	//https://github.com/Scrawk/Brunetons-Improved-Atmospheric-Scattering  这个写的也不错
	[RequireComponent(typeof(ScatteringSetting))]
	[ExecuteInEditMode]
	public class RuntimeSkySetting : MonoBehaviour
	{
		// Look up table update mode, it's better to use everyframe mode when you're in edit mode, need change params frequently.
		public LUTUpdateMode lutUpdateMode = LUTUpdateMode.OnStart;

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
		[NonSerialized] private RenderTexture m_IntergalCPDensityLUT;

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

		private void Awake()
		{
			m_Camera = Camera.main;
		}

		private void Start()
		{
			if (lutUpdateMode == LUTUpdateMode.OnStart)
			{
				PreComputeAll();
				UpdateMainLight();
				UpdateAmbient();
			}
		}

		private void OnDisable()
		{
			if (m_IntergalCPDensityLUT != null)
			{
				m_IntergalCPDensityLUT.Release();
				m_IntergalCPDensityLUT = null;
			}
		}

		private void Update()
		{
			if (lutUpdateMode == LUTUpdateMode.OnUpdate)
			{
				PreComputeAll();
				UpdateMainLight();
				UpdateAmbient();
			}
		}

		private void PreComputeAll()
		{
			SetCommonParams();

			if (computerShader == null)
			{
				Debug.LogWarningFormat("Computer shader for precompute scattering lut is empty");
				return;
			}

			ComputeIntegrateCPdensity();
			ComputeSunOnSurface();
			ComputeInScattering();
			ComputeHemiSphereRandomVectorLUT();
			ComputeAmbient();
		}

		private void SetCommonParams()
		{
			Shader.SetGlobalTexture(IDKeys.IntergalCPDensityLUT_ID, m_IntergalCPDensityLUT);
			//Shader.SetGlobalTexture(IDKeys.SunOnSurface_ID, m_SunOnSurfaceLUT);
			Shader.SetGlobalVector(IDKeys.DensityScaleHeight_ID, new Vector4(rDensityScale, mDensityScale));
			Shader.SetGlobalFloat(IDKeys.PlanetRadius_ID, planetRadius);
			Shader.SetGlobalFloat(IDKeys.AtmosphereHeight_ID, atmosphereHeight);
			Shader.SetGlobalFloat(IDKeys.SurfaceHeight_ID, surfaceHeight);
			Shader.SetGlobalVector(IDKeys.IncomingLight_ID, lightFromOuterSpace);
			Shader.SetGlobalFloat(IDKeys.SunIntensity_ID, sunIntensity);
			Shader.SetGlobalFloat(IDKeys.SunMieG_ID, sunMieG);
			m_Camera.CalculateFrustumCorners(m_Camera.rect, m_Camera.farClipPlane, Camera.MonoOrStereoscopicEye.Mono,
				m_FrustumCorners);
			for (int i = 0; i < 4; i++)
			{
				m_FrustumCorners[i] = m_Camera.transform.TransformDirection(m_FrustumCorners[i]);
				m_FrustumCornersVec4[i] = m_FrustumCorners[i];
				if (m_ShowFrustumCorners)
					Debug.DrawRay(m_Camera.transform.position, m_FrustumCorners[i], Color.blue);
			}

			Shader.SetGlobalVectorArray(IDKeys.FrustumCorners_ID, m_FrustumCornersVec4);
		}

		private void ComputeIntegrateCPdensity()
		{
			Utils.CheckOrCreateLUT(ref m_IntergalCPDensityLUT, integrateCPDensityLUTSize, RenderTextureFormat.RGFloat);

			int index = computerShader.FindKernel(IDKeys.csIntegrateCPDensity);
			computerShader.SetTexture(index, IDKeys.RWIntergalCPDensityLUT_ID, m_IntergalCPDensityLUT);

			Utils.Dispatch(computerShader, index, integrateCPDensityLUTSize);
		}

		private void ComputeSunOnSurface()
		{
			//really need hdr format
			Utils.CheckOrCreateLUT(ref m_SunOnSurfaceLUT, sunOnSurfaceLUTSize, RenderTextureFormat.DefaultHDR);

			int index = computerShader.FindKernel(IDKeys.CSSunOnSurface);

			computerShader.SetTexture(index, IDKeys.RWSunOnSurfaceLUT_ID, m_SunOnSurfaceLUT);
			computerShader.SetTexture(index, IDKeys.IntergalCPDensityLUT_ID, m_IntergalCPDensityLUT);

			Utils.Dispatch(computerShader, index, inScatteringLUTSize);
		}

		private void ComputeInScattering()
		{
			//really need hdr format
			Utils.CheckOrCreateLUT(ref m_InScatteringLUT, inScatteringLUTSize, RenderTextureFormat.DefaultHDR);

			int index = computerShader.FindKernel(IDKeys.CSInScattering);

			computerShader.SetTexture(index, IDKeys.RWInScatteringLUT_ID, m_InScatteringLUT);
			computerShader.SetTexture(index, IDKeys.IntergalCPDensityLUT_ID, m_IntergalCPDensityLUT);

			Utils.Dispatch(computerShader, index, inScatteringLUTSize);
		}

		private void ComputeHemiSphereRandomVectorLUT()
		{
			if (m_HemiSphereRandomNormlizedVecLUT == null)
			{
				m_HemiSphereRandomNormlizedVecLUT = new Texture2D(512, 1, TextureFormat.RGB24, false, true)
				{
					filterMode = FilterMode.Point,
				};

				m_HemiSphereRandomNormlizedVecLUT.Apply();
				for (int i = 0; i < m_HemiSphereRandomNormlizedVecLUT.width; i++)
				{
					var randomVec = UnityEngine.Random.onUnitSphere;
					m_HemiSphereRandomNormlizedVecLUT.SetPixel(i, 0,
						new Color(randomVec.x, Mathf.Abs(randomVec.y), randomVec.z));
				}
			}
		}

		private void ComputeAmbient()
		{
			var size = new Vector2Int(ambientLUTSize, 1);
			Utils.CheckOrCreateLUT(ref m_AmbientLUT, size, RenderTextureFormat.DefaultHDR);

			int index = computerShader.FindKernel(IDKeys.CSAmbient);

			computerShader.SetTexture(index, IDKeys.RWHemiSphereRandomNormlizedVecLUT_ID,
				m_HemiSphereRandomNormlizedVecLUT);
			computerShader.SetTexture(index, IDKeys.InScatteringLUT_ID, m_InScatteringLUT);
			computerShader.SetTexture(index, IDKeys.RWAmbientLUT_ID, m_AmbientLUT);

			Utils.Dispatch(computerShader, index, size);
		}
		
		private void UpdateMainLight()
		{
			if (mainLight == null)
			{
				return;
			}

			if (m_SunOnSurfaceLUTReadToCPU == null)
			{
				m_SunOnSurfaceLUTReadToCPU = new Texture2D(m_SunOnSurfaceLUT.width, m_SunOnSurfaceLUT.height,
					TextureFormat.RGBAHalf, false, true);
			}

			Utils.ReadRTPixelsBackToCPU(m_SunOnSurfaceLUT, m_SunOnSurfaceLUTReadToCPU);

			var lightDir = -mainLight.transform.forward;
			var cosAngle01 = Vector3.Dot(Vector3.up, lightDir) * 0.5 + 0.5;
			var height01 = surfaceHeight / atmosphereHeight;

			var col = m_SunOnSurfaceLUTReadToCPU.GetPixel((int) (cosAngle01 * m_SunOnSurfaceLUTReadToCPU.width),
				(int) (height01 * m_SunOnSurfaceLUTReadToCPU.height));
			Color lightColor;
			float intensity;
			Utils.HDRToColorIntensity(col, out lightColor, out intensity);

			//为什么这里是gamma?  因为 0.5 存进去linear是 0.21 取出来要反算一下
			mainLight.color = lightColor.gamma;
			mainLight.intensity = intensity;
			m_MainLightColor = col;
		}

		private void UpdateAmbient()
		{
			if (RenderSettings.ambientMode != AmbientMode.Flat)
			{
				return;
			}
			
			if (m_AmbientLUTReadToCPU == null)
			{
				m_AmbientLUTReadToCPU = new Texture2D(ambientLUTSize, 1, TextureFormat.RGB24, false, true);
			}

			Utils.ReadRTPixelsBackToCPU(m_AmbientLUT, m_AmbientLUTReadToCPU);

			var lightDir = -mainLight.transform.forward;
			var cosAngle01 = Vector3.Dot(Vector3.up, lightDir) * 0.5 + 0.5;

			var ambient = m_AmbientLUTReadToCPU.GetPixel((int) (cosAngle01 * m_AmbientLUTReadToCPU.width), 0);

			RenderSettings.ambientLight = ambient.gamma;
			m_AmbientColor = ambient;
		}

		
	}
}