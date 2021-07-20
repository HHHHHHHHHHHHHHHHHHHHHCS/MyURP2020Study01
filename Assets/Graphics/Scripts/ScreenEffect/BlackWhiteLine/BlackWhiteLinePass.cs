using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect.BlackWhiteLine
{
	public class BlackWhiteLinePass : ScriptableRenderPass
	{
		private const string k_tag = "BlackWhiteLine";

		private Material outlineMat, explodeMat;

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");

		private static readonly int tempRT_ID = Shader.PropertyToID("_TempTex");
		private static readonly RenderTargetIdentifier tempRT_RTI = new RenderTargetIdentifier(tempRT_ID);

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		// private int width, height;
		// private RenderTextureFormat colorFormat;
		private RenderTextureDescriptor desc;

		public BlackWhiteLinePass(Material outlineMat, Material explodeMat)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			this.outlineMat = outlineMat;
			this.explodeMat = explodeMat;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			// width = cameraTextureDescriptor.width;
			// height = cameraTextureDescriptor.height;
			// colorFormat = cameraTextureDescriptor.colorFormat;
			desc = cameraTextureDescriptor;
			desc.depthBufferBits = 0;
			desc.msaaSamples = 1;
			desc.memoryless |= RenderTextureMemoryless.Depth;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (outlineMat == null || explodeMat == null)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.GetTemporaryRT(tempRT_ID, desc); //width, height, 0, FilterMode.Point, colorFormat);

				cmd.SetGlobalTexture(SrcTex_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(tempRT_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, outlineMat);


				cmd.SetGlobalTexture(SrcTex_ID, tempRT_RTI);
				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, explodeMat);

				cmd.ReleaseTemporaryRT(tempRT_ID);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}