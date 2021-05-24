using System;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public class MyCustomPostProcessPass : ScriptableRenderPass
	{
		private const string k_tag = "MyCustomPostProcess";

		private const string k_bloomTag = "MyBloom";
		private const string k_uberTag = "MyUber";
		private const string k_stylizedTonemapTag = "StylizedTonemap";
		private const string k_finalTag = "MyFianl";

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private MyCustomPostProcessShaders shaders;

		private ProfilingSampler bloomProfilingSampler;
		private ProfilingSampler uberProfilingSampler;
		private ProfilingSampler stylizedTonemapProfilingSampler;
		private ProfilingSampler finalProfilingSampler;

		private GraphicsFormat defaultHDRFormat;

		private Camera camera;
		private RenderTextureDescriptor srcDesc;
		private int width, height;
		private bool isXR;


		public void Init(MyCustomPostProcessShaders _shaders)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			shaders = _shaders;

			bloomProfilingSampler = new ProfilingSampler(k_bloomTag);
			uberProfilingSampler = new ProfilingSampler(k_uberTag);
			stylizedTonemapProfilingSampler = new ProfilingSampler(k_stylizedTonemapTag);
			finalProfilingSampler = new ProfilingSampler(k_finalTag);

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
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			srcDesc = cameraTextureDescriptor;
			width = cameraTextureDescriptor.width;
			height = cameraTextureDescriptor.height;
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			camera = renderingData.cameraData.camera;
			isXR = renderingData.cameraData.camera.stereoActiveEye != Camera.MonoOrStereoscopicEye.Mono &&
			       renderingData.cameraData.camera.stereoTargetEye == StereoTargetEyeMask.Both;

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var stack = VolumeManager.instance.stack;
				var bloomSettings = stack.GetComponent<MyBloomPostProcess>();
				if (bloomSettings != null && bloomSettings.IsActive())
				{
					DoBloom(context, cmd, bloomSettings);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		#region HelpUtils

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");


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

		private static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier src, RenderTargetIdentifier dest,
			Material mat, int pass)
		{
			cmd.SetGlobalTexture(SrcTex_ID, src);
			cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
			CoreUtils.DrawFullScreen(cmd, mat, null, pass);
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

		private int bloomBufferTex_ID;

		private Level[] pyramid;


		public void InitBloom()
		{
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
				//我们不支持xr

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
				var lastDown = cameraColorTex_RTI;
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
	}
}