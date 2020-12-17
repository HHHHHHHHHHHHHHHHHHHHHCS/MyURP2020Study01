using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.HDR
{
	public class CustomTonemapPass : ScriptableRenderPass
	{
		private const string k_tag = "Custom Tonemap";

		private ProfilingSampler profilingSampler;
		private CustomTonemapSettings settings;
		private Material material;

		public CustomTonemapPass(Material _material)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			material = _material;
		}

		public void Setup(CustomTonemapSettings _customTonemapSettings)
		{
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