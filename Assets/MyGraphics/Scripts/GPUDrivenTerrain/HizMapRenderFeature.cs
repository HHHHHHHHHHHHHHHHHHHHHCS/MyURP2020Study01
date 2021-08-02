using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.GPUDrivenTerrain
{
	public class HizMapRenderFeature : ScriptableRendererFeature
	{
		[SerializeField] private ComputeShader computeShader;

		private HizMapRenderPass hizMapRenderPass;

		public override void Create()
		{
			if (computeShader == null)
			{
				return;
			}

			hizMapRenderPass = new HizMapRenderPass(computeShader)
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingTransparents
			};
		}

		private void OnDestroy()
		{
			if (hizMapRenderPass != null)
			{
				CoreUtils.Destroy(HizMapRenderPass.HiZMap);
			}
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			var cameraData = renderingData.cameraData;
			if (cameraData.isSceneViewCamera || cameraData.isPreviewCamera)
			{
				return;
			}

			if (cameraData.camera.name == "Preview Camera")
			{
				return;
			}

			if (hizMapRenderPass == null)
			{
				return;
			}

			renderer.EnqueuePass(hizMapRenderPass);
		}
	}
}