using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	public class FlipBookPass : ScriptableRenderPass
	{
		private const string k_tag = "FlipBook";

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private static readonly RenderTargetIdentifier cameraDepthTex_RTI =
			new RenderTargetIdentifier("_CameraDepthTexture");

		private List<FlipBookPage> pages = new List<FlipBookPage>();

		private MaterialPropertyBlock mpb;
		private Mesh mesh;
		private Material material;

		private float speed;
		private float time;

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

		public void Setup(float _speed, float _time)
		{
			speed = _speed;
			time = _time > 0 ? _time : time;
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
				if (time > 0)
				{
					pages[pageIndex].StartFlipping(cmd, speed, time, cameraColorTex_RTI);
					pageIndex = (pageIndex + 1) % pages.Count;
				}

				

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
					, cameraDepthTex_RTI, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);

				foreach (var page in pages)
				{
					page.LoopFlipping(mpb);

					cmd.DrawMesh(mesh, Matrix4x4.identity, material, 0, 0, mpb);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}