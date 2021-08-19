using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.ScreenEffect
{
	public class ScreenEffectFeature : ScriptableRendererFeature
	{
		public static ScriptableRenderPass renderPass;

		private ScriptableRenderPass screenEffectPass;

		public override void Create()
		{
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			var settings = VolumeManager.instance.stack.GetComponent<ScreenEffectPostProcess>();

			if (settings == null || !settings.IsActive())
			{
				screenEffectPass = null;
				return;
			}

			if (settings.onlyGameView.value && (renderingData.cameraData.cameraType != CameraType.Game ||
			                                    renderingData.cameraData.camera.name == "Preview Camera"))
			{
				return;
			}

			if (settings.useCustom.value == false)
			{
				var pass = screenEffectPass as ScreenEffectPass;
				if (pass == null)
				{
					pass = new ScreenEffectPass();
					pass.Init();
					screenEffectPass = pass;
				}

				pass.Setup(settings);
				pass.renderPassEvent = settings.renderPassEvent.value;
				renderer.EnqueuePass(pass);
			}
			else
			{
				var pass = renderPass;
				if (pass != null)
				{
					pass.renderPassEvent = settings.renderPassEvent.value;
					renderer.EnqueuePass(pass);
				}
			}
		}
	}
}