using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.HDR
{
	public class CustomTonemapFeature : ScriptableRendererFeature
	{
		private CustomTonemapPass customTonemapPass;
		private Material customTonemapMaterial;

		public override void Create()
		{
			customTonemapMaterial = CoreUtils.CreateEngineMaterial("MyRP/HDR/CustomTonemap");
			customTonemapPass = new CustomTonemapPass(customTonemapMaterial);
			customTonemapPass.renderPassEvent =
				RenderPassEvent.BeforeRenderingPostProcessing; //AfterRenderingPostProcessing;
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (renderingData.postProcessingEnabled)
			{
				var settings = VolumeManager.instance.stack.GetComponent<CustomTonemapSettings>();
				if (settings != null && settings.IsActive())
				{
					customTonemapPass.Setup(renderer.cameraColorTarget, settings);
					renderer.EnqueuePass(customTonemapPass);
				}
			}
		}
	}
}