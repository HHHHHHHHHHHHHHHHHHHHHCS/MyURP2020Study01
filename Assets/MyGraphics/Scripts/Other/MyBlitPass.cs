using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Other
{
	public class MyBlitPass : ScriptableRenderPass
	{
		private const string k_tag = "My Blit Pass";
		private static readonly int s_sourceTex_ID = Shader.PropertyToID("_SourceTex");
		private static readonly int s_scaleBiasRt_ID = Shader.PropertyToID("_ScaleBiasRt");

		private static readonly RenderTargetIdentifier s_final_RTI =
			new RenderTargetIdentifier("_AfterPostProcessTexture");


		private Material blitMaterial;
		private ProfilingSampler profilingSampler;
		private string rtName;

		public MyBlitPass(Material _blitMaterial)
		{
			blitMaterial = _blitMaterial;
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void Setup(string _rtName)
		{
			rtName = _rtName;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);

			using (new ProfilingScope(cmd, profilingSampler))
			{
				CoreUtils.SetRenderTarget(cmd, s_final_RTI);
				var rti = new RenderTargetIdentifier(rtName);
				cmd.SetGlobalTexture(s_sourceTex_ID, rti);

				ref CameraData cameraData = ref renderingData.cameraData;
				float flipSign = (cameraData.IsCameraProjectionMatrixFlipped()) ? -1.0f : 1.0f;
				Vector4 scaleBiasRt = (flipSign < 0.0f)
					? new Vector4(flipSign, 1.0f, -1.0f, 1.0f)
					: new Vector4(flipSign, 0.0f, 1.0f, 1.0f);
				cmd.SetGlobalVector(s_scaleBiasRt_ID, scaleBiasRt);

				cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, blitMaterial);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}
	}
}