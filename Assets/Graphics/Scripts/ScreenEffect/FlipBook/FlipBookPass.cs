using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	public class FlipBookPass : ScriptableRenderPass
	{
		private const string k_tag = "ScreenEffect";

		private List<FlipBookPage> pages = new List<FlipBookPage>();

		private MaterialPropertyBlock mpb;
		private Mesh mesh;
		private Material material;
		
		private int pageIndex = 0;

		public void Init(Mesh _mesh, Shader _shader, List<FlipBookPage> _pages)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			renderPassEvent = RenderPassEvent.AfterRenderingTransparents;

			mesh = _mesh;
			material = new Material(_shader);
			pages = _pages;
			mpb = new MaterialPropertyBlock();
		}

		public void OnDestroy()
		{
			if (material != null)
			{
				Object.DestroyImmediate(material);
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (material == null)
			{
				return;
			}
			
			
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				for (int i = 0; i < pages.Count; i++)
				{
					cmd.DrawMesh(mesh, Matrix4x4.identity, material, 0, 0, mpb);
				}
				
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}