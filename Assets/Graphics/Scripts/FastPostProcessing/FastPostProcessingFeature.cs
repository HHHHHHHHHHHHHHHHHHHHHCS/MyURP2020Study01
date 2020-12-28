using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.FastPostProcessing
{
	public class FastPostProcessingFeature : ScriptableRendererFeature
	{
		[Serializable]
		public enum ToneMapperType
		{
			None = 0,
			ACES,
			Dawson,
			Hable,
			Photographic,
			Reinhart,
		}


		[Serializable]
		public class MyFastPostProcessingSettings
		{
			//Sharpen
			//--------------------
			[Header("Sharpen"), SerializeField] public bool sharpen = true;
			[Range(0.1f, 4.0f), SerializeField] public float sharpenIntensity = 2.0f;

			[Range(0.00005f, 0.0008f), SerializeField]
			public float sharpenSize = 2.0f;

			//Bloom
			[Header("Bloom"), SerializeField] public bool bloom = true;
			[Range(0.01f, 2048), SerializeField] public float bloomSize = 512;
			[Range(0.00f, 3.0f), SerializeField] public float bloomAmount = 1.0f;
			[Range(0.0f, 3.0f), SerializeField] public float bloomPower = 1.0f;

			//ToneMapper
			[Header("ToneMapper"), SerializeField] public ToneMapperType toneMapper = ToneMapperType.ACES;
			// [HideInInspector] public bool userLutEnabled = true;
			// [HideInInspector] public Vector4 userLutParams;
			[SerializeField] public Texture2D userLutTexture = null;
			[SerializeField] public float exposure = 1.0f;
			[Range(0.0f, 1.0f), SerializeField] public float lutContribution = 0.5f;
			[SerializeField] public bool dithering = false;


			//Gamma Correction
			[Header("Gamma Correction"), SerializeField]
			public bool gammaCorrection = false;
		}

		#region KeyID

		private const string UserLutEnable_ID = "_USERLUT_ENABLE";
		private readonly int UserLutTex_ID = Shader.PropertyToID("_UserLutTex");
		private readonly int UserLutParams_ID = Shader.PropertyToID("_UserLutParams");

		#endregion
		
		#region Properties

		private MyFastPostProcessingSettings settings;

		private Shader shader;
		private Material postProcessMaterial;

		#endregion

		public override void Create()
		{
			Init();
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			var volume = renderingData.cameraData.camera.GetComponent<FastPostProcessingVolume>();
			if (volume == null || !volume.IsActive)
			{
				return;
			}
		}


		private void Init()
		{
			if (shader == null)
			{
				shader = Shader.Find("MyRP/FastPostProcessing/FastPostProcessing");
			}
			
			SafeDestroy(postProcessMaterial);
			if (postProcessMaterial == null && shader != null)
			{
				postProcessMaterial = new Material(shader);
			}
		}

		private void UpdateMaterialProperties(FastPostProcessingVolume volume, bool isForce = false)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("Material Or Shader NULL");
				return;
			}

			MyFastPostProcessingSettings vs = volume.settings;

			//TODO:
			//
			// if (m_Sharpen)
			// {
			// 	m_PostProcessMaterial.SetFloat("_SharpenSize", m_SharpenSize);
			// 	m_PostProcessMaterial.SetFloat("_SharpenIntensity", m_SharpenIntensity);
			// }
			//
			// if (m_Bloom)
			// {
			// 	m_PostProcessMaterial.SetFloat("_BloomSize", m_BloomSize);
			// 	m_PostProcessMaterial.SetFloat("_BloomAmount", m_BloomAmount);
			// 	m_PostProcessMaterial.SetFloat("_BloomPower", m_BloomPower);
			// }
			//
			// if (m_ToneMapper != ToneMapper.None)
			// 	m_PostProcessMaterial.SetFloat("_Exposure", m_Exposure);
			//
			// if (m_UserLutEnabled)
			// {
			// 	m_PostProcessMaterial.SetVector("_UserLutParams", m_UserLutParams);
			// 	m_PostProcessMaterial.SetTexture("_UserLutTex", m_UserLutTexture);
			// }

			if (isForce || settings.userLutTexture != vs.userLutTexture)
			{
				settings.userLutTexture = vs.userLutTexture;
				SetTexture(UserLutTex_ID, settings.userLutTexture);

				var userLutEnabled = settings.userLutTexture != null;
				SetKeyword(UserLutEnable_ID, userLutEnabled);

				if (userLutEnabled)
				{
					var userLutParams = new Vector4(1f / settings.userLutTexture.width,
						1f / settings.userLutTexture.height,
						settings.userLutTexture.height - 1, settings.lutContribution);
					
					SetVector(UserLutParams_ID, userLutParams);
				}
			}

			if (isForce || settings.sharpen != vs.sharpen)
			{
				settings.sharpen = vs.sharpen;
				SetKeyword("_SHARPEN", settings.sharpen);
			}

			if (isForce || settings.bloom != vs.bloom)
			{
				settings.bloom = vs.bloom;
				SetKeyword("_BLOOM", settings.bloom);
			}

			if (isForce || settings.bloom != vs.bloom)
			{
				settings.bloom = vs.bloom;
				SetKeyword("_BLOOM", settings.bloom);
			}

			if (isForce || settings.dithering != vs.dithering)
			{
				settings.dithering = vs.dithering;
				SetKeyword("_DITHERING", settings.dithering);
			}

			if (isForce || settings.gammaCorrection != vs.gammaCorrection)
			{
				settings.gammaCorrection = vs.gammaCorrection;
				SetKeyword("_GAMMA_CORRECTION", settings.gammaCorrection);
			}

			if (isForce || settings.toneMapper != vs.toneMapper)
			{
				settings.toneMapper = vs.toneMapper;
				switch (settings.toneMapper)
				{
					case ToneMapperType.None:
						SetKeyword("_ACES", false);
						SetKeyword("_DAWSON", false);
						SetKeyword("_HABLE", false);
						SetKeyword("_PHOTOGRAPHIC", false);
						SetKeyword("_REINHART", false);
						break;
					case ToneMapperType.ACES:
						SetKeyword("_ACES", true);
						break;
					case ToneMapperType.Dawson:
						SetKeyword("_DAWSON", true);
						break;
					case ToneMapperType.Hable:
						SetKeyword("_HABLE", true);
						break;
					case ToneMapperType.Photographic:
						SetKeyword("_PHOTOGRAPHIC", true);
						break;
					case ToneMapperType.Reinhart:
						SetKeyword("_REINHART", true);
						break;
				}
			}
		}

		private void SetKeyword(string keyword, bool isEnabled)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("FastPostProcessing Material is null");
				return;
			}

			if (isEnabled)
			{
				postProcessMaterial.EnableKeyword(keyword);
			}
			else
			{
				postProcessMaterial.DisableKeyword(keyword);
			}
		}

		private void SetTexture(int keywordID, Texture2D texture)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("FastPostProcessing Material is null");
				return;
			}

			postProcessMaterial.SetTexture(keywordID, texture);
		}

		private void SetFloat(int keywordID, float value)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("FastPostProcessing Material is null");
				return;
			}

			postProcessMaterial.SetFloat(keywordID, value);
		}
		
		private void SetVector(int keywordID, Vector4 value)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("FastPostProcessing Material is null");
				return;
			}

			postProcessMaterial.SetVector(keywordID, value);
		}

		private void SafeDestroy(Material material)
		{
			if (material == null)
			{
				return;
			}

#if UNITY_EDITOR
			DestroyImmediate(material);
#else
			Destroy(material);
#endif
		}
	}
}