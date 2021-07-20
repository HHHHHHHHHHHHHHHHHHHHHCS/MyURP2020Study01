using System;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.TAA
{
	public class TAARenderFeature : ScriptableRendererFeature
	{
		public Shader velocityBufferShader;
		public Shader reprojectionShader;

		private Material velocityBufferMaterial;
		private Material reprojectionMaterial;

		private bool isCreate;
		private TAAFrustumJitterRenderPass taaFrustumJitterRenderPass;
		private TAAVelocityBufferRenderPass taaVelocityBufferRenderPass;
		private TAAReprojectionRenderPass taaReprojectionRenderPass;

		public override void Create()
		{
			isCreate = false;
			if (!CreateMaterial(ref velocityBufferShader, ref velocityBufferMaterial))
			{
				return;
			}

			if (!CreateMaterial(ref reprojectionShader, ref reprojectionMaterial))
			{
				return;
			}

			taaFrustumJitterRenderPass = new TAAFrustumJitterRenderPass
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingOpaques
			};
			taaVelocityBufferRenderPass = new TAAVelocityBufferRenderPass(velocityBufferMaterial)
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing - 2
			};
			taaReprojectionRenderPass = new TAAReprojectionRenderPass(reprojectionMaterial)
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing - 1
			};

			isCreate = true;
		}

		private void OnDestroy()
		{
			isCreate = false;

			CoreUtils.Destroy(velocityBufferMaterial);
			velocityBufferMaterial = null;

			CoreUtils.Destroy(reprojectionMaterial);
			reprojectionMaterial = null;

			if (taaReprojectionRenderPass != null)
			{
				taaReprojectionRenderPass.OnDispose();
				taaReprojectionRenderPass = null;
			}
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

			if (!isCreate || !renderingData.postProcessingEnabled)
			{
				return;
			}

			var settings = VolumeManager.instance.stack.GetComponent<TAAPostProcess>();
			if (!settings.IsActive())
			{
				return;
			}

			taaFrustumJitterRenderPass.Setup(settings, cam);
			renderer.EnqueuePass(taaFrustumJitterRenderPass);
			taaVelocityBufferRenderPass.Setup(settings);
			renderer.EnqueuePass(taaVelocityBufferRenderPass);
			taaReprojectionRenderPass.Setup(settings);
			renderer.EnqueuePass(taaReprojectionRenderPass);
		}

		public bool CreateMaterial(ref Shader shader, ref Material mat)
		{
			if (shader == null)
			{
				if (mat != null)
				{
					CoreUtils.Destroy(mat);
					mat = null;
				}

				Debug.LogError("Shader is null,can't create!");
				return false;
			}

			if (mat == null)
			{
				mat = CoreUtils.CreateEngineMaterial(shader);
			}
			else if (mat.shader != shader)
			{
				CoreUtils.Destroy(mat);
				mat = CoreUtils.CreateEngineMaterial(shader);
			}

			return true;
		}
	}
}