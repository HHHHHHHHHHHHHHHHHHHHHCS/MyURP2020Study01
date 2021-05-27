using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect
{
	public class ScreenEffectPass : ScriptableRenderPass
	{
		private const string k_tag = "ScreenEffect";

		private ScreenEffectPostProcess settings;

		private static readonly int tempRT_ID = Shader.PropertyToID("_TempTex");
		private static readonly RenderTargetIdentifier tempRT_RTI = new RenderTargetIdentifier(tempRT_ID);

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		// private int width, height;
		// private RenderTextureFormat colorFormat;
		private RenderTextureDescriptor desc;

		public void Setup(ScreenEffectPostProcess _settings)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			settings = _settings;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			// width = cameraTextureDescriptor.width;
			// height = cameraTextureDescriptor.height;
			// colorFormat = cameraTextureDescriptor.colorFormat;
			desc = cameraTextureDescriptor;
			desc.depthBufferBits = 0;
			desc.msaaSamples = 1;
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			settings = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var mat = settings.effectMat.value;

				if (settings.inputMainTex.value)
				{
					cmd.GetTemporaryRT(tempRT_ID, desc);//width, height, 0, FilterMode.Point, colorFormat);
					
					cmd.Blit(cameraColorTex_RTI, tempRT_RTI);
					
					cmd.SetGlobalTexture("_SrcTex", tempRT_RTI);
					cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare
						, RenderBufferStoreAction.Store);
					
					CoreUtils.DrawFullScreen(cmd, settings.effectMat.value);
					
					cmd.ReleaseTemporaryRT(tempRT_ID);
				}
				else
				{
					CoreUtils.DrawFullScreen(cmd, mat);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}