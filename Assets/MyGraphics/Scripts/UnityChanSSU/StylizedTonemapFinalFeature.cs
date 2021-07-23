using MyGraphics.Scripts.ScreenEffect;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.UnityChanSSU
{
	public class StylizedTonemapFinalFeature : ScriptableRendererFeature
	{
		public Shader stylizedTonemapFinalShader;

		private Material stylizedTonemapFinalMaterial;
		private StylizedTonemapFinalPass stylizedTonemapFinalPass;


		public override void Create()
		{
#if UNITY_EDITOR
			if (stylizedTonemapFinalMaterial != null &&
			    stylizedTonemapFinalMaterial.shader != stylizedTonemapFinalShader)
			{
				DestroyImmediate(stylizedTonemapFinalMaterial);
				stylizedTonemapFinalMaterial = null;
			}
#endif

			if (stylizedTonemapFinalShader == null)
			{
				return;
			}

			stylizedTonemapFinalMaterial = CoreUtils.CreateEngineMaterial(stylizedTonemapFinalShader);
			stylizedTonemapFinalPass = new StylizedTonemapFinalPass()
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
			};
			stylizedTonemapFinalPass.Init(stylizedTonemapFinalMaterial);
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (stylizedTonemapFinalPass == null || renderingData.postProcessingEnabled == false
			                                     || stylizedTonemapFinalMaterial == null)
			{
				return;
			}

			var settings = VolumeManager.instance.stack.GetComponent<StylizedTonemapFinalPostProcess>();

			if (settings.IsActive() == false)
			{
				return;
			}

			stylizedTonemapFinalPass.Setup(settings);
			renderer.EnqueuePass(stylizedTonemapFinalPass);
		}
	}
}