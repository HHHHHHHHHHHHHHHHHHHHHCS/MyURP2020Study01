using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.Common
{
	public class XPostProcessingFeature : ScriptableRendererFeature
	{
		public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

		public XPostProcessAssets assets = new XPostProcessAssets();

		private XPostProcessingPass xPostProcessingPass;
		
		public override void Create()
		{
			xPostProcessingPass = new XPostProcessingPass(assets)
			{
				renderPassEvent = renderPassEvent
			};
		}

		protected override void Dispose(bool disposing)
		{
			AbsXPostProcessingParameters.ClearSamplerDict();
			assets.DestroyMaterials();
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			renderer.EnqueuePass(xPostProcessingPass);
		}
	}
}