using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessingEffects
{
	public class ImageProcessImageRenderFeature : ScriptableRendererFeature
	{
		public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
		public Shader sharpenV1Shader;


		private bool isCreate;

		private Material sharpenV1Material;

		private SharpenV1RenderPass sharpenV1RenderPass;


		public override void Create()
		{
			isCreate = false;
			if (!ToolsHelper.CreateMaterial(ref sharpenV1Shader, ref sharpenV1Material))
			{
				return;
			}

			sharpenV1RenderPass = new SharpenV1RenderPass(sharpenV1Material)
			{
				renderPassEvent = renderPassEvent
			};
			isCreate = true;
		}


		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (!isCreate || !renderingData.postProcessingEnabled)
			{
				return;
			}

			renderer.EnqueuePass(sharpenV1RenderPass);
		}
	}
}