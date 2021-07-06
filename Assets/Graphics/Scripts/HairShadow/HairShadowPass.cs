using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.HairShadow
{
	public class HairShadowPass : ScriptableRenderPass
	{
		private static readonly int TempRT_ID = Shader.PropertyToID("_HairSolidColor");

		public Material depthMat;
		private HairShadowFeature.Setting setting;


		private ShaderTagId shaderTag;
		private FilteringSettings hairFiltering;
		private FilteringSettings faceFiltering;

		public HairShadowPass(HairShadowFeature.Setting _setting, Material _material)
		{
			setting = _setting;
			depthMat = _material;
			profilingSampler = new ProfilingSampler("HairShadow");
			shaderTag = new ShaderTagId("UniversalForward");
			RenderQueueRange queue = new RenderQueueRange();
			queue.lowerBound = Mathf.Min(setting.queueMax, setting.queueMin);
			queue.upperBound = Mathf.Min(setting.queueMax, setting.queueMin);
			hairFiltering = new FilteringSettings(queue, -1, setting.hairRenderLayer);
			faceFiltering = new FilteringSettings(queue, -1, setting.faceRenderLayer);
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			var desc = cameraTextureDescriptor;
			cmd.GetTemporaryRT(TempRT_ID, desc);
			ConfigureTarget(TempRT_ID);
			ConfigureClear(ClearFlag.All, Color.black);
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			cmd.ReleaseTemporaryRT(TempRT_ID);
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get();
			using (new ProfilingScope(cmd, profilingSampler))
			{
				/*
				var draw1 = CreateDrawingSettings(shaderTag, ref renderingData,
					renderingData.cameraData.defaultOpaqueSortFlags);
				draw1.overrideMaterial = depthMat;
				draw1.overrideMaterialPassIndex = 1;
				context.DrawRenderers(renderingData.cullResults, ref draw1, ref faceFiltering);
				*/
				var draw2 = CreateDrawingSettings(shaderTag, ref renderingData,
					renderingData.cameraData.defaultOpaqueSortFlags);
				draw2.overrideMaterial = depthMat;
				draw2.overrideMaterialPassIndex = 0;
				context.DrawRenderers(renderingData.cullResults, ref draw2, ref hairFiltering);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}