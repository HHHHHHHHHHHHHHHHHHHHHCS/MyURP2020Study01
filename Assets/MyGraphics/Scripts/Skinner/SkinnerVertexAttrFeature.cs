using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerVertexAttrFeature : ScriptableRendererFeature
	{
		private SkinnerVertexAttrPass skinnerVertexAttrPass;

		public override void Create()
		{
			skinnerVertexAttrPass = new SkinnerVertexAttrPass()
			{
				renderPassEvent = RenderPassEvent.BeforeRendering
			};
		}

		private void OnDisable()
		{
			skinnerVertexAttrPass?.OnDestroy();
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (!Application.isPlaying)
			{
				return;
			}

			if (SkinnerSource.Instance == null)
			{
				skinnerVertexAttrPass?.OnDestroy();
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
	}
}