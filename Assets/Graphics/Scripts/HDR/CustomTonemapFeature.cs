using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.HDR
{
	public class CustomTonemapFeature : ScriptableRendererFeature
	{
		public override void Create()
		{
			CustomTonemapSettings tt;
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
		}
	}
}
