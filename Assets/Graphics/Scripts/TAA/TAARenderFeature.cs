using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.TAA
{
	public class TAARenderFeature : ScriptableRendererFeature
	{
		private TAAFrustumJitterRenderPass taaFrustumJitterRenderPass;

		public override void Create()
		{
			taaFrustumJitterRenderPass = new TAAFrustumJitterRenderPass
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingOpaques
			};
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			var cam = renderingData.cameraData.camera;
			if (cam.cameraType != CameraType.Game
#if UNITY_EDITOR
			    || cam.name.StartsWith("Preview")
#endif
			)
			{
				return;
			}

			var settings = VolumeManager.instance.stack.GetComponent<TAAPostProcess>();
			if (!settings.IsActive())
			{
				return;
			}

			taaFrustumJitterRenderPass.Setup(settings);
			renderer.EnqueuePass(taaFrustumJitterRenderPass);
		}
	}
}