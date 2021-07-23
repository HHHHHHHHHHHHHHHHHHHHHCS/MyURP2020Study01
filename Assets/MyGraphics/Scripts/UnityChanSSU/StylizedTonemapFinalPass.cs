using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.UnityChanSSU
{
	public class StylizedTonemapFinalPass : ScriptableRenderPass
	{
		private const string k_tag = "StylizedTonemapFinal";

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");
		private static readonly int Exposure_ID = Shader.PropertyToID("_Exposure");
		private static readonly int Saturation_ID = Shader.PropertyToID("_Saturation");
		private static readonly int Contrast_ID = Shader.PropertyToID("_Contrast");

		private static readonly int tempRT_ID = Shader.PropertyToID("_TempTex");
		private static readonly RenderTargetIdentifier tempRT_RTI = new RenderTargetIdentifier(tempRT_ID);

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private Material mat;
		private StylizedTonemapFinalPostProcess settings;


		public void Init(Material stylizedTonemapFinalMaterial)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			mat = stylizedTonemapFinalMaterial;
		}

		public void Setup(StylizedTonemapFinalPostProcess _settings)
		{
			settings = _settings;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			int width = cameraTextureDescriptor.width;
			int height = cameraTextureDescriptor.height;
			RenderTextureFormat format = cameraTextureDescriptor.colorFormat;
			cmd.GetTemporaryRT(tempRT_ID, width, height, 0, FilterMode.Point, format);
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			cmd.ReleaseTemporaryRT(tempRT_ID);
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			//其实存在一个问题
			//就是先进行HDR映射  导致后面的Bloom 效果不是很好
			//正确的流程是 Bloom  HDR映射
			//但是又不想改管线 所以emmm 偷懒
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.SetRenderTarget(tempRT_RTI, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
				cmd.SetGlobalTexture(SrcTex_ID, cameraColorTex_RTI);
				CoreUtils.DrawFullScreen(cmd, mat, null, 1);

				mat.SetFloat(Exposure_ID, settings.exposure.value);
				mat.SetFloat(Saturation_ID, settings.saturation.value);
				mat.SetFloat(Contrast_ID, settings.contrast.value);

				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
				cmd.SetGlobalTexture(SrcTex_ID, tempRT_RTI);
				CoreUtils.DrawFullScreen(cmd, mat, null, 0);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}