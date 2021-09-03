using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerFeature : ScriptableRendererFeature
	{
		public Shader particleKernelsShader;

		private SkinnerVertexAttrPass skinnerVertexAttrPass;
		private SkinnerParticleAttrPass skinnerParticleAttrPass;

		private Material particleKernelsMaterial;

		public SkinnerVertexAttrPass VertexAttrPass => skinnerVertexAttrPass;
		public SkinnerParticleAttrPass ParticleAttrPass => skinnerParticleAttrPass;


		public override void Create()
		{
			var queueEvent = RenderPassEvent.BeforeRendering;

			skinnerVertexAttrPass = new SkinnerVertexAttrPass()
			{
				renderPassEvent = queueEvent
			};

			skinnerParticleAttrPass = new SkinnerParticleAttrPass(this)
			{
				renderPassEvent = queueEvent
			};
		}

		private void OnDisable()
		{
			skinnerVertexAttrPass?.OnDestroy();
			skinnerParticleAttrPass?.OnDestroy();
			CoreUtils.Destroy(particleKernelsMaterial);
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (!Application.isPlaying)
			{
				return;
			}

			AddVertexAttrPass(renderer, ref renderingData);
			AddParticleAttrPass(renderer, ref renderingData);
		}

		private void AddVertexAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (SkinnerSource.Instance == null)
			{
				skinnerParticleAttrPass?.OnDestroy();
				return;
			}

			var model = SkinnerSource.Instance.Model;

			if (model == null)
			{
				skinnerVertexAttrPass?.OnDestroy();
				return;
			}


			skinnerVertexAttrPass.OnSetup(model);
			renderer.EnqueuePass(skinnerVertexAttrPass);
		}

		private void AddParticleAttrPass(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (particleKernelsShader == null)
			{
				CoreUtils.Destroy(particleKernelsMaterial);
				return;
			}

			if (SkinnerParticle.Instance == null)
			{
				skinnerParticleAttrPass?.OnDestroy();
				return;
			}

			var particle = SkinnerParticle.Instance;
			var template = particle.Template;

			if (template == null)
			{
				skinnerParticleAttrPass?.OnDestroy();
				return;
			}

			if (particleKernelsMaterial == null)
			{
				particleKernelsMaterial = CoreUtils.CreateEngineMaterial(particleKernelsShader);
			}

			skinnerParticleAttrPass.OnSetup(particle, particleKernelsMaterial);
			renderer.EnqueuePass(skinnerParticleAttrPass);
		}
	}
}