using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public class StylizedTonemapFinalPass : ScriptableRenderPass
	{
		private const string k_tag = "StylizedTonemapFinal";
		
		private static readonly int Exposure_ID = Shader.PropertyToID("_Exposure");
		private static readonly int Saturation_ID = Shader.PropertyToID("_Saturation");
		private static readonly int Contrast_ID = Shader.PropertyToID("_Contrast");

		private Material mat;
		private StylizedTonemapFinalPostProcess settings;


		public void Init(Material stylizedTonemapFinalMaterial)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			mat = stylizedTonemapFinalMaterial;
		}

		public void Setup(StylizedTonemapFinalPostProcess _settings)
		{
			settings = _settings;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				mat.SetFloat(Exposure_ID, settings.exposure.value);
				mat.SetFloat(Saturation_ID, settings.saturation.value);
				mat.SetFloat(Contrast_ID, settings.contrast.value);

				CoreUtils.DrawFullScreen(cmd, mat);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}