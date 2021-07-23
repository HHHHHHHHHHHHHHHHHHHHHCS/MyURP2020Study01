using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.ScreenEffect.BlackWhiteLine
{
	public class BlackWhiteLinePass : ScriptableRenderPass
	{
		private const string k_tag = "BlackWhiteLine";

		private Material effectMat;

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");
		private static readonly int SceneTex_ID = Shader.PropertyToID("_SceneTex");

		private static readonly int temp0RT_ID = Shader.PropertyToID("_Temp0Tex");
		private static readonly int temp1RT_ID = Shader.PropertyToID("_Temp1Tex");
		private static readonly RenderTargetIdentifier temp0RT_RTI = new RenderTargetIdentifier(temp0RT_ID);
		private static readonly RenderTargetIdentifier temp1RT_RTI = new RenderTargetIdentifier(temp1RT_ID);

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		// private int width, height;
		// private RenderTextureFormat colorFormat;
		private RenderTextureDescriptor desc;

		public BlackWhiteLinePass(Material effectMat)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			this.effectMat = effectMat;
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
			if (effectMat == null)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.GetTemporaryRT(temp0RT_ID, desc);
				cmd.GetTemporaryRT(temp1RT_ID, desc);

				cmd.SetGlobalTexture(SrcTex_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(temp0RT_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 0);


				cmd.SetGlobalTexture(SrcTex_ID, temp0RT_RTI);
				cmd.SetGlobalTexture(SceneTex_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(temp1RT_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 1);

				cmd.SetGlobalTexture(SrcTex_ID, temp1RT_RTI);
				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 2);

				cmd.ReleaseTemporaryRT(temp0RT_ID);
				cmd.ReleaseTemporaryRT(temp1RT_ID);
				
				//bake code
				/*
				cmd.GetTemporaryRT(temp0RT_ID, desc);
				cmd.GetTemporaryRT(temp1RT_ID, desc);

				cmd.SetGlobalTexture(SrcTex_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(temp0RT_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 0);


				cmd.SetGlobalTexture(SrcTex_ID, temp0RT_RTI);
				cmd.SetGlobalTexture(SceneTex_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(temp1RT_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 1);

				cmd.SetGlobalTexture(SrcTex_ID, temp1RT_RTI);
				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 2);

				cmd.ReleaseTemporaryRT(temp0RT_ID);
				cmd.ReleaseTemporaryRT(temp1RT_ID);
				*/
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}