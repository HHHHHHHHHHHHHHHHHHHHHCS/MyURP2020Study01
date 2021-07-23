using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.FastPostProcessing
{
	public class FastPostProcessingPass : ScriptableRenderPass
	{
		private const string k_tag = "FastPostProcessingPass";
		private static readonly ProfilingSampler profilingSampler = new ProfilingSampler(k_tag);

		private static readonly int MainTex_ID = Shader.PropertyToID("_MainTex");
		private const string k_TempTex = "_TempTex";
		private static readonly int TempTex_ID = Shader.PropertyToID(k_TempTex);
		private static readonly RenderTargetIdentifier TempTex_RTI = new RenderTargetIdentifier(k_TempTex);
		private static readonly RenderTargetIdentifier CameraColorTexture_RTI = new RenderTargetIdentifier("_CameraColorTexture");

		
		private Material mat;

		private RenderTextureDescriptor desc;

		public void Init(Material postProcessMaterial)
		{
			mat = postProcessMaterial;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			desc = cameraTextureDescriptor;
			desc.msaaSamples = 1;
			desc.mipCount = 1;
			desc.depthBufferBits = 0;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);

			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.GetTemporaryRT(TempTex_ID, desc);
				cmd.SetRenderTarget(TempTex_RTI, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
				cmd.SetGlobalTexture(MainTex_ID,CameraColorTexture_RTI);
				CoreUtils.DrawFullScreen(cmd, mat, null, 0);
				cmd.Blit(TempTex_RTI,CameraColorTexture_RTI);
				cmd.ReleaseTemporaryRT(TempTex_ID);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}
	}
}