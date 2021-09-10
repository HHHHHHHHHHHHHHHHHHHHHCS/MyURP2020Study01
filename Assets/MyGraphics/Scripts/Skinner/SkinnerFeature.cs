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
		public Shader glitchKernelsShader;

		private SkinnerVertexAttrPass vertexAttrPass;
		private SkinnerParticleAttrPass particleAttrPass;
		private SkinnerTrailAttrPass trailAttrPass;
		private SkinnerGlitchAttrPass glitchAttrPass;

		private Material particleKernelsMaterial;
		private Material trailKernelsMaterial;
		private Material glitchernelsMaterial;


		public override void Create()
		{
			DoDestroy();

			var queueEvent = RenderPassEvent.BeforeRendering;

			vertexAttrPass = new SkinnerVertexAttrPass()
			{
				renderPassEvent = queueEvent
			};

			particleAttrPass = new SkinnerParticleAttrPass()
			{
				renderPassEvent = queueEvent
			};

			trailAttrPass = new SkinnerTrailAttrPass()
			{
				renderPassEvent = queueEvent
			};

			glitchAttrPass = new SkinnerGlitchAttrPass()
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
			glitchAttrPass?.OnDestroy();
			CoreUtils.Destroy(particleKernelsMaterial);
			CoreUtils.Destroy(trailKernelsMaterial);
			CoreUtils.Destroy(glitchernelsMaterial);
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

			//其实应该添加如果看不见就不渲染了
			AddVertexAttrPass(renderer, ref renderingData);
			AddParticleAttrPass(renderer, ref renderingData);
			AddTrailAttrPass(renderer, ref renderingData);
			AddGlitchAttrPass(renderer, ref renderingData);
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
				CoreUtils.Destroy(particleKernelsMaterial);
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
				CoreUtils.Destroy(trailKernelsMaterial);
				trailKernelsMaterial = CoreUtils.CreateEngineMaterial(trailKernelsShader);
			}

			trailAttrPass.OnSetup(SkinnerManager.Instance.Trails, trailKernelsMaterial);
			renderer.EnqueuePass(trailAttrPass);
		}

		private void AddGlitchAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (SkinnerManager.Instance.Glitches.Count == 0 || glitchKernelsShader == null)
			{
				glitchAttrPass?.OnDestroy();
				CoreUtils.Destroy(glitchernelsMaterial);
				return;
			}

			if (glitchernelsMaterial == null || glitchernelsMaterial.shader != glitchKernelsShader)
			{
				CoreUtils.Destroy(glitchernelsMaterial);
				glitchernelsMaterial = CoreUtils.CreateEngineMaterial(glitchKernelsShader);
			}

			glitchAttrPass.OnSetup(SkinnerManager.Instance.Glitches, glitchernelsMaterial);
			renderer.EnqueuePass(glitchAttrPass);
		}
	}
}