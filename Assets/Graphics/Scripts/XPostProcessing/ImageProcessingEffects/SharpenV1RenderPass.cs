using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessingEffects
{
	public class SharpenV1RenderPass : ScriptableRenderPass
	{
		private const string k_tag = "SharpenV1";

		private static readonly int Strength_ID = Shader.PropertyToID("_Strength");
		private static readonly int Threshold_ID = Shader.PropertyToID("_Threshold");

		private Material material;

		public SharpenV1RenderPass(Material mat)
		{
			material = mat;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			var settings = VolumeManager.instance.stack.GetComponent<SharpenV1PostProcess>();
			if (!settings.enableEffect.value)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				material.SetFloat(Strength_ID, settings.strength.value);
				material.SetFloat(Threshold_ID, settings.threshold.value);
				CoreUtils.DrawFullScreen(cmd, material);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}