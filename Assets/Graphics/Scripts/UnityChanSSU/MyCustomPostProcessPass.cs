using System;
using System.CodeDom;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace Graphics.Scripts.UnityChanSSU
{
	public class MyCustomPostProcessPass : ScriptableRenderPass
	{
		#region RenderPipeline

		private const string k_tag = "MyCustomPostProcess";

		private MyCustomPostProcessShaders shaders;
		private MyCustomPostProcessAssets assets;

		private GraphicsFormat defaultHDRFormat;

		// private Camera camera;
		private RenderTextureDescriptor srcDesc;
		private RenderTextureFormat format;
		private int width, height;
		private bool isXR, allowDynamicResolution;


		public void Init(MyCustomPostProcessShaders _shaders, MyCustomPostProcessAssets _assets)
		{
			profilingSampler = new ProfilingSampler(k_tag);

			shaders = _shaders;
			assets = _assets;

			// Texture format pre-lookup
			if (SystemInfo.IsFormatSupported(GraphicsFormat.B10G11R11_UFloatPack32,
				FormatUsage.Linear | FormatUsage.Render))
			{
				defaultHDRFormat = GraphicsFormat.B10G11R11_UFloatPack32;
			}
			else
			{
				defaultHDRFormat = QualitySettings.activeColorSpace == ColorSpace.Linear
					? GraphicsFormat.R16G16B16_SFloat
					: GraphicsFormat.R16G16B16_SNorm;
			}

			InitBloom();
			InitUber();
			InitStylizedTonemapFinal();
			InitSMAA();
			InitFinal();
		}

		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			srcDesc = renderingData.cameraData.cameraTargetDescriptor;
			width = srcDesc.width;
			height = srcDesc.height;
			format = srcDesc.colorFormat;
			allowDynamicResolution = renderingData.cameraData.camera.allowDynamicResolution;

			// camera = renderingData.cameraData.camera;
			isXR = renderingData.cameraData.camera.stereoActiveEye != Camera.MonoOrStereoscopicEye.Mono &&
			       renderingData.cameraData.camera.stereoTargetEye == StereoTargetEyeMask.Both;
		}

		public override void OnCameraCleanup(CommandBuffer cmd)
		{
			ReleaseBloomTex(cmd);
			ReleaseTempRT(cmd);
		}

		public void OnDestroy()
		{
			DestroyChromaticAberration();
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				SetupTempRT();

				var stack = VolumeManager.instance.stack;

				bool enableUber = false;


				var bloomSettings = stack.GetComponent<MyBloomPostProcess>();
				if (bloomSettings != null && bloomSettings.IsActive())
				{
					enableUber = true;
					DoBloom(context, cmd, bloomSettings);
				}
				else
				{
					DisableBloom();
				}

				var myVignetteSettings = stack.GetComponent<MyVignettePostProcess>();
				if (myVignetteSettings != null && myVignetteSettings.IsActive())
				{
					enableUber = true;
					DoVignette(context, cmd, myVignetteSettings);
				}
				else
				{
					DisableVignette();
				}

				var myChromaticAberrationSettings = stack.GetComponent<MyChromaticAberrationPostProcess>();
				if (myChromaticAberrationSettings != null && myChromaticAberrationSettings.IsActive())
				{
					enableUber = true;
					DoChromaticAberration(context, cmd, myChromaticAberrationSettings);
				}
				else
				{
					DisableChromaticAberration();
				}

				var stylizedTonemapSettings = stack.GetComponent<StylizedTonemapFinalPostProcess>();
				bool haveStylized = stylizedTonemapSettings != null && stylizedTonemapSettings.IsActive();

				//这里不写FXAA
				bool haveSMAA =
					renderingData.cameraData.antialiasing == AntialiasingMode.SubpixelMorphologicalAntiAliasing &&
					SystemInfo.graphicsDeviceType != GraphicsDeviceType.OpenGLES2;
				
				bool uberIsTemp = haveStylized || haveSMAA;

				if (SrcIsFinal(cmd))
				{
					uberIsTemp = true;
				}


				if (enableUber)
				{
					DoUber(context, cmd, uberIsTemp);
					SwapRT();
				}


				if (haveStylized)
				{
					DoStylizedTonemapFinal(context, cmd, stylizedTonemapSettings);
					SwapRT();
				}


				// SM Anti-aliasing
				if (haveSMAA)
				{
					SetupSMAA(renderingData.cameraData.antialiasingQuality);
					DoSMAA(context, cmd);
					SwapRT();
				}

				//TODO:FXAA


				if (uberIsTemp && !SrcIsFinal(cmd))
				{
					DoDithering(context, cmd);
					DoFinal(context, cmd);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		#endregion

		#region HelpUtils

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");

		private static readonly int TempRT0_ID = Shader.PropertyToID("_TempRT0");

		private static readonly int TempRT1_ID = Shader.PropertyToID("_TempRT1");

		private static readonly RenderTargetIdentifier TempRT0_RTI = new RenderTargetIdentifier(TempRT0_ID);

		private static readonly RenderTargetIdentifier TempRT1_RTI = new RenderTargetIdentifier(TempRT1_ID);

		private int src, dest;


		private void SetupTempRT()
		{
			src = -1;
			dest = -1;
		}

		private void ReleaseTempRT(CommandBuffer cmd)
		{
			if (src != -1)
			{
				cmd.ReleaseTemporaryRT(src);
			}

			if (dest != -1)
			{
				cmd.ReleaseTemporaryRT(dest);
			}
		}

		private RenderTargetIdentifier GetSrc(CommandBuffer cmd)
		{
			if (src == -1)
			{
				return cameraColorTex_RTI;
			}

			return src == TempRT0_ID ? TempRT0_RTI : TempRT1_RTI;
		}

		private RenderTargetIdentifier GetDest(CommandBuffer cmd)
		{
			// return BuiltinRenderTextureType.CameraTarget;
			if (dest == -1)
			{
				var desc = GetRenderDescriptor(width, height, defaultHDRFormat);

				if (src == TempRT1_ID || src == -1)
				{
					cmd.GetTemporaryRT(TempRT0_ID, desc);
					dest = TempRT0_ID;
				}
				else if (src == TempRT0_ID)
				{
					cmd.GetTemporaryRT(TempRT1_ID, desc);
					dest = TempRT1_ID;
				}
			}

			return dest == TempRT0_ID ? TempRT0_RTI : TempRT1_RTI;
		}


		private void SwapRT()
		{
			CoreUtils.Swap(ref src, ref dest);
		}

		private bool SrcIsFinal(CommandBuffer cmd) => GetSrc(cmd) == cameraColorTex_RTI;


		private RenderTextureDescriptor GetRenderDescriptor(int _width, int _height, GraphicsFormat _format)
		{
			var desc = srcDesc;
			desc.width = _width;
			desc.height = _height;
			desc.depthBufferBits = 0;
			desc.msaaSamples = 1;
			desc.graphicsFormat = _format;
			return desc;
		}

		private static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier dest,
			Material mat, int pass = 0)
		{
			cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
			CoreUtils.DrawFullScreen(cmd, mat, null, pass);
		}

		private static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier src, RenderTargetIdentifier dest,
			Material mat, int pass)
		{
			cmd.SetGlobalTexture(SrcTex_ID, src);
			DrawFullScreen(cmd, dest, mat, pass);
		}

		//2^x
		private static float Exp2(float x)
		{
			return Mathf.Exp(x * 0.69314718055994530941723212145818f);
		}

		#endregion

		#region MyBloom

		private enum Pass
		{
			Prefilter13 = 0,
			Prefilter4,
			Downsample13,
			Downsample4,
			UpsampleTent,
			UpsampleBox,
		}

		private struct Level
		{
			public int down_id;
			public int up_id;

			public RenderTargetIdentifier down_rti;
			public RenderTargetIdentifier up_rti;
		}

		private const string k_bloomTag = "MyBloom";

		private const int k_MaxPyramidSize = 16; // Just to make sure we handle 64k screens... Future-proof!

		private const string k_BLOOM_LOW = "BLOOM_LOW";
		private const string k_BLOOM = "BLOOM";

		private static readonly int SampleScale_ID = Shader.PropertyToID("_SampleScale");
		private static readonly int Threshold_ID = Shader.PropertyToID("_Threshold");
		private static readonly int Params_ID = Shader.PropertyToID("_Params");
		private static readonly int BloomTex_ID = Shader.PropertyToID("_BloomTex");

		private static readonly int Bloom_DirtTileOffset_ID = Shader.PropertyToID("_Bloom_DirtTileOffset");
		private static readonly int Bloom_Settings_ID = Shader.PropertyToID("_Bloom_Settings");
		private static readonly int Bloom_Color_ID = Shader.PropertyToID("_Bloom_Color");
		private static readonly int Bloom_DirtTex_ID = Shader.PropertyToID("_Bloom_DirtTex");

		private ProfilingSampler bloomProfilingSampler;

		private int bloomBufferTex_ID;

		private Level[] pyramid;


		public void InitBloom()
		{
			bloomProfilingSampler = new ProfilingSampler(k_bloomTag);

			pyramid = new Level[k_MaxPyramidSize];

			for (int i = 0; i < k_MaxPyramidSize; i++)
			{
				int down = Shader.PropertyToID("_BloomMipDown" + i);
				int up = Shader.PropertyToID("_BloomMipUp" + i);

				pyramid[i] = new Level
				{
					down_id = down,
					down_rti = new RenderTargetIdentifier(down),
					up_id = up,
					up_rti = new RenderTargetIdentifier(up),
				};
			}
		}

		private void DoBloom(ScriptableRenderContext context, CommandBuffer cmd, MyBloomPostProcess settings)
		{
			var bloomMat = shaders.BloomMaterial;
			var uberMat = shaders.UberMaterial;


			Assert.IsNotNull(bloomMat);
			Assert.IsNotNull(uberMat);

			using (new ProfilingScope(cmd, bloomProfilingSampler))
			{
				//我们这套是没有autoExposureTexture的  原来的PPSV2是有的
				//但是默认的图片是white  所以直接忽略了

				// Negative anamorphic ratio values distort vertically - positive is horizontal
				float ratio = Mathf.Clamp(settings.anamorphicRatio.value, -1, 1);
				float rw = ratio < 0 ? -ratio : 0f;
				float rh = ratio > 0 ? ratio : 0f;

				// Do bloom on a half-res buffer, full-res doesn't bring much and kills performances on
				// fillrate limited platforms
				int tw = Mathf.FloorToInt(width / (2f - rw));
				int th = Mathf.FloorToInt(height / (2f - rh));
				bool singlePassDoubleWide = isXR;
				int tw_stereo = isXR ? tw * 2 : tw;

				// Determine the iteration count
				// tw th 也决定了上升下降的次数
				// settings.diffusion -> 上升下降的次数
				int s = Mathf.Max(tw, th);
				float logs = Mathf.Log(s, 2f) + Mathf.Min(settings.diffusion.value, 10f) - 10f;
				int logs_i = Mathf.FloorToInt(logs);
				int iterations = Mathf.Clamp(logs_i, 1, k_MaxPyramidSize);
				float sampleScale = 0.5f + logs - logs_i;
				shaders.BloomMaterial.SetFloat(SampleScale_ID, sampleScale);

				// Prefiltering parameters
				float lthresh = settings.threshold.value; //Mathf.GammaToLinearSpace() 原来的写法  我们自己的直接当linear算了
				float knee = lthresh * settings.softKnee.value + 1e-5f;
				var threshold = new Vector4(lthresh, lthresh - knee, knee * 2f, 0.25f / knee);
				bloomMat.SetVector(Threshold_ID, threshold);
				float lclamp = settings.clamp.value;
				bloomMat.SetVector(Params_ID, new Vector4(lclamp, 0f, 0f, 0f));

				int qualityOffset = settings.fastMode.value ? 1 : 0;

				// Downsample
				var lastDown = GetSrc(cmd);
				for (int i = 0; i < iterations; i++)
				{
					int mipDown = pyramid[i].down_id;
					var mipDown_rti = pyramid[i].down_rti;
					int mipUp = pyramid[i].up_id;

					int pass = i == 0
						? (int) Pass.Prefilter13 + qualityOffset
						: (int) Pass.Downsample13 + qualityOffset;

					var desc = GetRenderDescriptor(tw_stereo, th, defaultHDRFormat);
					cmd.GetTemporaryRT(mipDown, desc, FilterMode.Bilinear);
					cmd.GetTemporaryRT(mipUp, desc, FilterMode.Bilinear);

					DrawFullScreen(cmd, lastDown, mipDown_rti, bloomMat, pass);

					lastDown = mipDown_rti;
					tw_stereo = (singlePassDoubleWide && ((tw_stereo / 2) % 2 > 0)) ? 1 + tw_stereo / 2 : tw_stereo / 2;
					tw_stereo = Mathf.Max(tw_stereo, 1);
					th = Mathf.Max(th / 2, 1);
				}

				// Upsample
				var lastUp = pyramid[iterations - 1].down_rti;
				for (int i = iterations - 2; i >= 0; i--)
				{
					var mipDown_rti = pyramid[i].down_rti;
					var mipUp_rti = pyramid[i].up_rti;
					cmd.SetGlobalTexture(BloomTex_ID, mipDown_rti);
					DrawFullScreen(cmd, lastUp, mipUp_rti, bloomMat, (int) Pass.UpsampleTent + qualityOffset);
					lastUp = mipUp_rti;
				}

				bloomBufferTex_ID = pyramid[0].up_id;

				var linearColor = settings.color.value;
				float intensity = Exp2(settings.intensity.value / 10f) - 1f;
				var shaderSettings = new Vector4(sampleScale, intensity, settings.dirtIntensity.value, iterations);

				//Texture2D.blackTexture 其实可以换成1x1/2x2的像素图片
				//采样更速度  占用更小
				var dirtTexture = settings.dirtTexture.value == null
					? Texture2D.blackTexture
					: settings.dirtTexture.value;

				var dirtRatio = (float) dirtTexture.width / (float) dirtTexture.height;
				var screenRatio = (float) width / (float) height;
				var dirtTileOffset = new Vector4(1f, 1f, 0f, 0f);

				if (dirtRatio > screenRatio)
				{
					dirtTileOffset.x = screenRatio / dirtRatio;
					dirtTileOffset.z = (1f - dirtTileOffset.x) * 0.5f;
				}
				else if (screenRatio > dirtRatio)
				{
					dirtTileOffset.y = dirtRatio / screenRatio;
					dirtTileOffset.w = (1f - dirtTileOffset.y) * 0.5f;
				}

				//uber
				//------------

				if (settings.fastMode.value)
				{
					uberMat.EnableKeyword(k_BLOOM_LOW);
				}
				else
				{
					uberMat.EnableKeyword(k_BLOOM);
				}

				uberMat.SetVector(Bloom_DirtTileOffset_ID, dirtTileOffset);
				uberMat.SetVector(Bloom_Settings_ID, shaderSettings);
				uberMat.SetColor(Bloom_Color_ID, linearColor);
				uberMat.SetTexture(Bloom_DirtTex_ID, dirtTexture);
				cmd.SetGlobalTexture(BloomTex_ID, lastUp);

				// Cleanup
				for (int i = 0; i < iterations; i++)
				{
					if (pyramid[i].down_rti != lastUp)
						cmd.ReleaseTemporaryRT(pyramid[i].down_id);
					if (pyramid[i].up_rti != lastUp)
						cmd.ReleaseTemporaryRT(pyramid[i].up_id);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}

		private void DisableBloom()
		{
			var uberMat = shaders.UberMaterial;

			if (uberMat)
			{
				uberMat.DisableKeyword(k_BLOOM_LOW);
				uberMat.DisableKeyword(k_BLOOM);
			}
		}

		private void ReleaseBloomTex(CommandBuffer cmd)
		{
			//-1 0  基本都是unity target rt 而不是 我们自己getTemp的
			if (bloomBufferTex_ID > 0)
			{
				cmd.ReleaseTemporaryRT(bloomBufferTex_ID);
				bloomBufferTex_ID = 0;
			}
		}

		#endregion

		#region MyVignette

		private const string k_VIGNETTE = "VIGNETTE";

		private static readonly int VignetteColor_ID = Shader.PropertyToID("_Vignette_Color");
		private static readonly int VignetteCenter_ID = Shader.PropertyToID("_Vignette_Center");
		private static readonly int VignetteSettings_ID = Shader.PropertyToID("_Vignette_Settings");
		private static readonly int VignetteMask_ID = Shader.PropertyToID("_Vignette_Mask");
		private static readonly int VignetteOpacity_ID = Shader.PropertyToID("_Vignette_Opacity");
		private static readonly int VignetteMode_ID = Shader.PropertyToID("_Vignette_Mode");

		private void DoVignette(ScriptableRenderContext context, CommandBuffer cmd,
			MyVignettePostProcess settings)
		{
			var uberMat = shaders.UberMaterial;

			Assert.IsNotNull(uberMat);

			uberMat.EnableKeyword(k_VIGNETTE);

			//因为这里是单纯的材质设置  所以不需要怎么ProfilingScope
			uberMat.SetColor(VignetteColor_ID, settings.color.value);

			if (settings.mode.value == VignetteMode.Classic)
			{
				uberMat.SetFloat(VignetteMode_ID, 0f);
				uberMat.SetVector(VignetteCenter_ID, settings.center.value);
				float roundness = (1f - settings.roundness.value) * 6f + settings.roundness.value;
				uberMat.SetVector(VignetteSettings_ID,
					new Vector4(settings.intensity.value * 3f, settings.smoothness.value * 5f, roundness,
						settings.rounded.value ? 1f : 0f));
			}
			else // Masked
			{
				uberMat.SetFloat(VignetteMode_ID, 1f);
				uberMat.SetTexture(VignetteMask_ID, settings.mask.value);
				uberMat.SetFloat(VignetteOpacity_ID, Mathf.Clamp01(settings.opacity.value));
			}
		}

		private void DisableVignette()
		{
			var uberMat = shaders.UberMaterial;

			if (uberMat)
			{
				uberMat.DisableKeyword(k_VIGNETTE);
			}
		}

		#endregion

		#region MyChromaticAberration

		private const string k_CHROMATIC_ABERRATION_LOW = "CHROMATIC_ABERRATION_LOW";
		private const string k_CHROMATIC_ABERRATION = "CHROMATIC_ABERRATION";

		private static readonly int ChromaticAberrationAmount_ID = Shader.PropertyToID("_ChromaticAberration_Amount");

		private static readonly int ChromaticAberrationSpectralLut_ID =
			Shader.PropertyToID("_ChromaticAberration_SpectralLut");

		private Texture2D internalSpectralLut;

		private void DoChromaticAberration(ScriptableRenderContext context, CommandBuffer cmd,
			MyChromaticAberrationPostProcess settings)
		{
			var uberMat = shaders.UberMaterial;

			Assert.IsNotNull(uberMat);

			var spectralLut = settings.spectralLut.value;

			if (spectralLut == null)
			{
				if (internalSpectralLut == null)
				{
					internalSpectralLut = new Texture2D(3, 1, TextureFormat.RGB24, false)
					{
						name = "Chromatic Aberration Spectrum Lookup",
						filterMode = FilterMode.Bilinear,
						wrapMode = TextureWrapMode.Clamp,
						anisoLevel = 0,
						hideFlags = HideFlags.DontSave
					};

					internalSpectralLut.SetPixels(new[]
					{
						new Color(1f, 0f, 0f),
						new Color(0f, 1f, 0f),
						new Color(0f, 0f, 1f)
					});

					internalSpectralLut.Apply();
				}

				spectralLut = internalSpectralLut;
			}

			bool fastMode = settings.fastMode.value;

			uberMat.EnableKeyword(fastMode
				? k_CHROMATIC_ABERRATION_LOW
				: k_CHROMATIC_ABERRATION);

			uberMat.SetFloat(ChromaticAberrationAmount_ID, settings.intensity.value * 0.05f);
			uberMat.SetTexture(ChromaticAberrationSpectralLut_ID, spectralLut);
		}

		private void DisableChromaticAberration()
		{
			var uberMat = shaders.UberMaterial;

			if (uberMat)
			{
				uberMat.DisableKeyword(k_CHROMATIC_ABERRATION_LOW);
				uberMat.DisableKeyword(k_CHROMATIC_ABERRATION);
			}
		}

		private void DestroyChromaticAberration()
		{
			if (internalSpectralLut != null)
			{
				Object.DestroyImmediate(internalSpectralLut);
				internalSpectralLut = null;
			}
		}

		#endregion

		#region MyUber

		private const string k_uberTag = "MyUber";

		private ProfilingSampler uberProfilingSampler;

		private void InitUber()
		{
			uberProfilingSampler = new ProfilingSampler(k_uberTag);
		}

		private void DoUber(ScriptableRenderContext context, CommandBuffer cmd, bool uberIsTemp)
		{
			var uberMat = shaders.UberMaterial;

			Assert.IsNotNull(uberMat);

			using (new ProfilingScope(cmd, uberProfilingSampler))
			{
				DrawFullScreen(cmd, GetSrc(cmd), uberIsTemp ? GetDest(cmd) : cameraColorTex_RTI, uberMat, 0);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}

		#endregion

		#region StylizedTonemapFinal

		private const string k_stylizedTonemapTag = "StylizedTonemap";

		private static readonly int Exposure_ID = Shader.PropertyToID("_Exposure");
		private static readonly int Saturation_ID = Shader.PropertyToID("_Saturation");
		private static readonly int Contrast_ID = Shader.PropertyToID("_Contrast");

		private ProfilingSampler stylizedTonemapProfilingSampler;

		private void InitStylizedTonemapFinal()
		{
			stylizedTonemapProfilingSampler = new ProfilingSampler(k_stylizedTonemapTag);
		}


		private void DoStylizedTonemapFinal(ScriptableRenderContext context, CommandBuffer cmd,
			StylizedTonemapFinalPostProcess settings)
		{
			var stylizedTonemapMat = shaders.StylizedTonemapMaterial;

			Assert.IsNotNull(stylizedTonemapMat);

			using (new ProfilingScope(cmd, stylizedTonemapProfilingSampler))
			{
				stylizedTonemapMat.SetFloat(Exposure_ID, settings.exposure.value);
				stylizedTonemapMat.SetFloat(Saturation_ID, settings.saturation.value);
				stylizedTonemapMat.SetFloat(Contrast_ID, settings.contrast.value);

				DrawFullScreen(cmd, GetSrc(cmd), GetDest(cmd), stylizedTonemapMat, 0);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}

		#endregion

		#region MySMAA
		
		enum SMAAPass
		{
			EdgeDetection = 0,
			BlendWeights = 3,
			NeighborhoodBlending = 6
		}

		private const string k_smaaTag = "MySMAA";

		private static readonly int AreaTex_ID = Shader.PropertyToID("_AreaTex");
		private static readonly int SearchTex_ID = Shader.PropertyToID("_SearchTex");
		private static readonly int BlendTex_ID = Shader.PropertyToID("_BlendTex");


		private static readonly int SMAA_Flip_ID = Shader.PropertyToID("_SMAA_Flip");
		private static readonly int SMAA_Flop_ID = Shader.PropertyToID("_SMAA_Flop");

		private static readonly RenderTargetIdentifier SMAA_Flip_RTI = new RenderTargetIdentifier(SMAA_Flip_ID);
		private static readonly RenderTargetIdentifier SMAA_Flop_RTI = new RenderTargetIdentifier(SMAA_Flop_ID);
		
		private ProfilingSampler smaaProfilingSampler;
		
		private AntialiasingQuality ssmaaQuality = AntialiasingQuality.High;


		private void InitSMAA()
		{
			smaaProfilingSampler = new ProfilingSampler(k_smaaTag);
		}

		private void SetupSMAA(AntialiasingQuality _smaaQuality)
		{
			ssmaaQuality = _smaaQuality;
		}
		

		private void DoSMAA(ScriptableRenderContext context, CommandBuffer cmd)
		{
			//https://zhuanlan.zhihu.com/p/342211163
			
			//TODO:有BUG   要用全屏的QUAD   三角形会光栅化不正确
			
			//这里没有做VR XR的 不支持跳过
			
			var smaaMat = shaders.SMAAMaterial;

			Assert.IsNotNull(smaaMat);

			using (new ProfilingScope(cmd, smaaProfilingSampler))
			{

				smaaMat.SetTexture(AreaTex_ID, assets.smaaLutsArea);
				smaaMat.SetTexture(SearchTex_ID, assets.smaaLutsSearch);

				cmd.GetTemporaryRT(SMAA_Flip_ID, width, height, 0, FilterMode.Bilinear, format,
					RenderTextureReadWrite.Linear, 1, false, RenderTextureMemoryless.None,
					allowDynamicResolution);
				cmd.GetTemporaryRT(SMAA_Flop_ID, width, height, 0, FilterMode.Bilinear, format,
					RenderTextureReadWrite.Linear, 1, false, RenderTextureMemoryless.None,
					allowDynamicResolution);
				
				DrawFullScreen(cmd, GetSrc(cmd), SMAA_Flip_RTI, smaaMat, (int) SMAAPass.EdgeDetection + (int)ssmaaQuality);
				DrawFullScreen(cmd, SMAA_Flip_RTI, SMAA_Flop_RTI, smaaMat, (int)SMAAPass.BlendWeights + (int)ssmaaQuality);
				cmd.SetGlobalTexture(BlendTex_ID,SMAA_Flop_RTI);
				DrawFullScreen(cmd, GetSrc(cmd), GetDest(cmd), smaaMat, (int)SMAAPass.NeighborhoodBlending);

				cmd.ReleaseTemporaryRT(SMAA_Flip_ID);
				cmd.ReleaseTemporaryRT(SMAA_Flop_ID);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}

		#endregion

		#region Dither

		private static readonly int DitheringTex_ID = Shader.PropertyToID("_DitheringTex");
		private static readonly int Dithering_Coords_ID = Shader.PropertyToID("_Dithering_Coords");

		private int noiseTextureIndex = 0;
		private System.Random random = new System.Random(1234);

		private void DoDithering(ScriptableRenderContext context, CommandBuffer cmd)
		{
			//主要是为了抖动颜色  用眼睛补颜色   比如8抖10

			var finalMat = shaders.FinalMaterial;

			Assert.IsNotNull(finalMat);

			Assert.IsTrue(assets.ditherBlueNoises != null && assets.ditherBlueNoises.Length > 0);

			if (++noiseTextureIndex >= assets.ditherBlueNoises.Length)
			{
				noiseTextureIndex = 0;
			}

			float rndOffsetX = (float) random.NextDouble();
			float rndOffsetY = (float) random.NextDouble();

			var noiseTex = assets.ditherBlueNoises[noiseTextureIndex];

			finalMat.SetTexture(DitheringTex_ID, noiseTex);
			finalMat.SetVector(Dithering_Coords_ID, new Vector4(
				(float) width / noiseTex.width,
				(float) height / noiseTex.height,
				rndOffsetX,
				rndOffsetY
			));
		}

		#endregion

		#region MyFinal

		private const string k_finalTag = "MyFianl";

		private ProfilingSampler finalProfilingSampler;

		private void InitFinal()
		{
			finalProfilingSampler = new ProfilingSampler(k_finalTag);
		}

		private void DoFinal(ScriptableRenderContext context, CommandBuffer cmd)
		{
			var finalMat = shaders.FinalMaterial;

			Assert.IsNotNull(finalMat);

			using (new ProfilingScope(cmd, finalProfilingSampler))
			{
				DrawFullScreen(cmd, GetSrc(cmd), cameraColorTex_RTI, finalMat, 0);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}

		#endregion
	}
}