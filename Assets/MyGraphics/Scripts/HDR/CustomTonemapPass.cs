using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.HDR
{
	public class CustomTonemapPass : ScriptableRenderPass
	{
		private const string k_tag = "Custom Tonemap";
		
		private static readonly int s_ScaleBiasID = Shader.PropertyToID("_ScaleBiasRt");

		private ProfilingSampler profilingSampler;
		private CustomTonemapSettings settings;
		private RenderTargetIdentifier colorTarget;
		private Material material;

		public CustomTonemapPass(Material _material)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			material = _material;
		}

		public void Setup(RenderTargetIdentifier input, CustomTonemapSettings _customTonemapSettings)
		{
			colorTarget = input;
			settings = _customTonemapSettings;
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
				// scaleBias.x = flipSign
				// scaleBias.y = scale
				// scaleBias.z = bias
				// scaleBias.w = unused
				float flipSign = (renderingData.cameraData.IsCameraProjectionMatrixFlipped()) ? -1.0f : 1.0f;
				Vector4 scaleBias = (flipSign < 0.0f)
					? new Vector4(flipSign, 1.0f, -1.0f, 1.0f)
					: new Vector4(flipSign, 0.0f, 1.0f, 1.0f);
				cmd.SetGlobalVector(s_ScaleBiasID, scaleBias);
				
				material.SetFloat("_Exposure", settings.exposure.value);
				material.SetFloat("_Saturation", settings.saturation.value);
				material.SetFloat("_Contrast", settings.contrast.value);
				cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, material, 0, 0);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}
	}
}