using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerFeature : ScriptableRendererFeature
	{
		public Shader particleKernelsShader;
		public Shader trailKernelsShader;

		private SkinnerVertexAttrPass vertexAttrPass;
		private SkinnerParticleAttrPass particleAttrPass;
		private SkinnerTrailAttrPass trailAttrPass;

		private Material particleKernelsMaterial;
		private Material trailKernelsMaterial;

		public SkinnerVertexAttrPass VertexAttrPass => vertexAttrPass;
		public SkinnerParticleAttrPass ParticleAttrPass => particleAttrPass;
		public SkinnerTrailAttrPass TrailAttrPass => trailAttrPass;


		public override void Create()
		{
			DoDestroy();

			var queueEvent = RenderPassEvent.BeforeRendering;

			vertexAttrPass = new SkinnerVertexAttrPass()
			{
				renderPassEvent = queueEvent
			};

			particleAttrPass = new SkinnerParticleAttrPass(this)
			{
				renderPassEvent = queueEvent
			};

			trailAttrPass = new SkinnerTrailAttrPass(this)
			{
				renderPassEvent = queueEvent
			};
		}

		private void OnDisable()
		{
			DoDestroy();
		}

		private void DoDestroy()
		{
			vertexAttrPass?.OnDestroy();
			particleAttrPass?.OnDestroy();
			trailAttrPass?.OnDestroy();
			CoreUtils.Destroy(particleKernelsMaterial);
			CoreUtils.Destroy(trailKernelsMaterial);
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
#if UNITY_EDITOR
			// if (UnityEditor.EditorApplication.isPaused)
			// {
			// 	return;
			// }

			if (!Application.isPlaying)
			{
				return;
			}
#endif

			if (renderingData.cameraData.cameraType != CameraType.Game
			    || renderingData.cameraData.camera.name == "Preview Camera")
			{
				return;
			}

			if (!SkinnerManager.CheckInstance())
			{
				DoDestroy();
				return;
			}

			var instance = SkinnerManager.Instance;

			if (instance.Sources.Count == 0)
			{
				DoDestroy();
				return;
			}

			instance.Update();

			//其实应该添加如果看不见就不渲染了  否则会图片残留
			AddVertexAttrPass(renderer, ref renderingData);
			AddParticleAttrPass(renderer, ref renderingData);
			AddTrailAttrPass(renderer, ref renderingData);
		}
		
		private void AddVertexAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			vertexAttrPass.OnSetup(SkinnerManager.Instance.Sources);
			renderer.EnqueuePass(vertexAttrPass);
		}

		private void AddParticleAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (SkinnerManager.Instance.Particles.Count == 0 || particleKernelsShader == null)
			{
				particleAttrPass?.OnDestroy();
				CoreUtils.Destroy(particleKernelsMaterial);
				return;
			}

			if (particleKernelsMaterial == null || particleKernelsMaterial.shader != particleKernelsShader)
			{
				particleKernelsMaterial = CoreUtils.CreateEngineMaterial(particleKernelsShader);
			}

			particleAttrPass.OnSetup(SkinnerManager.Instance.Particles, particleKernelsMaterial);
			renderer.EnqueuePass(particleAttrPass);
		}

		private void AddTrailAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (SkinnerManager.Instance.Trails.Count == 0 || trailKernelsShader == null)
			{
				trailAttrPass?.OnDestroy();
				CoreUtils.Destroy(trailKernelsMaterial);
				return;
			}

			if (trailKernelsMaterial == null || trailKernelsMaterial.shader != trailKernelsShader)
			{
				trailKernelsMaterial = CoreUtils.CreateEngineMaterial(trailKernelsShader);
			}

			trailAttrPass.OnSetup(SkinnerManager.Instance.Trails, trailKernelsMaterial);
			renderer.EnqueuePass(trailAttrPass);
		}
	}
}