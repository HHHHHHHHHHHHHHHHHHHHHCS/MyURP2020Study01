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

		private const string Sharpen_ID = "_SHARPEN";
		private readonly int SharpenSize_ID = Shader.PropertyToID("_SharpenSize");
		private readonly int SharpenIntensity_ID = Shader.PropertyToID("_SharpenIntensity");

		private const string Bloom_ID = "_BLOOM";
		private readonly int BloomSize_ID = Shader.PropertyToID("_BloomSize");
		private readonly int BloomAmount_ID = Shader.PropertyToID("_BloomAmount");
		private readonly int BloomPower_ID = Shader.PropertyToID("_BloomPower");


		private const string ACES_ID = "_TONEMAPPER_ACES";
		private const string DAWSON_ID = "_TONEMAPPER_DAWSON";
		private const string HABLE_ID = "_TONEMAPPER_HABLE";
		private const string PHOTOGRAPHIC_ID = "_TONEMAPPER_PHOTOGRAPHIC";
		private const string REINHART_ID = "_TONEMAPPER_REINHART";
		private readonly int Exposure_ID = Shader.PropertyToID("_Exposure");
		private const string Dithering_ID = "_DITHERING";
		private const string UserLutEnable_ID = "_USERLUT_ENABLE";
		private readonly int UserLutTex_ID = Shader.PropertyToID("_UserLutTex");
		private readonly int UserLutParams_ID = Shader.PropertyToID("_UserLutParams");

		private const string GammaCorrection_ID = "_GAMMA_CORRECTION";

		#endregion

		#region Properties

		private MyFastPostProcessingSettings settings;
		private FastPostProcessingPass fastPostProcessingPass;

		private Shader shader;
		private Material postProcessMaterial;

		#endregion

		public override void Create()
		{
			Init();
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (fastPostProcessingPass == null || renderingData.postProcessingEnabled == false ||
			    renderingData.cameraData.cameraType != CameraType.Game)
			{
				return;
			}

			var volume = renderingData.cameraData.camera.GetComponent<FastPostProcessingVolume>();
			if (volume == null || !volume.IsActive)
			{
				return;
			}

			if (settings == null)
			{
				settings = new MyFastPostProcessingSettings();
				UpdateMaterialProperties(volume, true);
			}
			else
			{
				UpdateMaterialProperties(volume, false);
			}

			renderer.EnqueuePass(fastPostProcessingPass);
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

			fastPostProcessingPass = new FastPostProcessingPass()
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
			};
			fastPostProcessingPass.Init(postProcessMaterial);
		}

		//本来这些材质更新应该要写到Pass里面的 这里偷懒就不改了
		private void UpdateMaterialProperties(FastPostProcessingVolume volume, bool isForce = false)
		{
			if (postProcessMaterial == null)
			{
				Debug.LogError("Material Or Shader is null");
				return;
			}

			MyFastPostProcessingSettings vs = volume.settings;

			//Sharpen
			if (isForce || settings.sharpen != vs.sharpen)
			{
				settings.sharpen = vs.sharpen;
				SetKeyword(Sharpen_ID, settings.sharpen);
			}

			if (settings.sharpen)
			{
				if (isForce || settings.sharpenSize != vs.sharpenSize)
				{
					settings.sharpenSize = vs.sharpenSize;
					SetFloat(SharpenSize_ID, settings.sharpenSize);
				}

				if (isForce || settings.sharpenIntensity != vs.sharpenIntensity)
				{
					settings.sharpenIntensity = vs.sharpenIntensity;
					SetFloat(SharpenIntensity_ID, settings.sharpenIntensity);
				}
			}


			//Bloom
			if (isForce || settings.bloom != vs.bloom)
			{
				settings.bloom = vs.bloom;
				SetKeyword(Bloom_ID, settings.bloom);
			}

			if (settings.bloom)
			{
				if (isForce || settings.bloomSize != vs.bloomSize)
				{
					settings.bloomSize = vs.bloomSize;
					SetFloat(BloomSize_ID, settings.bloomSize);
				}

				if (isForce || settings.bloomAmount != vs.bloomAmount)
				{
					settings.bloomAmount = vs.bloomAmount;
					SetFloat(BloomAmount_ID, settings.bloomAmount);
				}

				if (isForce || settings.bloomPower != vs.bloomPower)
				{
					settings.bloomPower = vs.bloomPower;
					SetFloat(BloomPower_ID, settings.bloomPower);
				}
			}


			//ToneMapper
			if (isForce || settings.toneMapper != vs.toneMapper)
			{
				settings.toneMapper = vs.toneMapper;
				switch (settings.toneMapper)
				{
					case ToneMapperType.None:
						SetKeyword(ACES_ID, false);
						SetKeyword(DAWSON_ID, false);
						SetKeyword(HABLE_ID, false);
						SetKeyword(PHOTOGRAPHIC_ID, false);
						SetKeyword(REINHART_ID, false);
						break;
					case ToneMapperType.ACES:
						SetKeyword(ACES_ID, true);
						break;
					case ToneMapperType.Dawson:
						SetKeyword(DAWSON_ID, true);
						break;
					case ToneMapperType.Hable:
						SetKeyword(HABLE_ID, true);
						break;
					case ToneMapperType.Photographic:
						SetKeyword(PHOTOGRAPHIC_ID, true);
						break;
					case ToneMapperType.Reinhart:
						SetKeyword(REINHART_ID, true);
						break;
				}
			}

			if (settings.toneMapper != ToneMapperType.None)
			{
				if (isForce || settings.exposure != vs.exposure)
				{
					settings.exposure = vs.exposure;
					SetFloat(Exposure_ID, settings.exposure);
				}

				if (isForce || settings.dithering != vs.dithering)
				{
					settings.dithering = vs.dithering;
					SetKeyword(Dithering_ID, settings.dithering);
				}
			}


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

			if (isForce || settings.gammaCorrection != vs.gammaCorrection)
			{
				settings.gammaCorrection = vs.gammaCorrection;
				SetKeyword(GammaCorrection_ID, settings.gammaCorrection);
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