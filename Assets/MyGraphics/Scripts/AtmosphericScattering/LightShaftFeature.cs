using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.AtmosphericScattering
{
	public class LightShaftFeature : ScriptableRendererFeature
	{
		public Shader lightShaftShader;
		public Texture2D ditherTex;

		private Material lightShaftMaterial;
		private LightShaftPass lightShaftPass;

		public override void Create()
		{
			if (lightShaftMaterial != null && lightShaftMaterial.shader != lightShaftShader)
			{
				DestroyImmediate(lightShaftMaterial);
			}

			if (lightShaftShader == null)
			{
				return;
			}

			lightShaftMaterial = CoreUtils.CreateEngineMaterial(lightShaftShader);
			
			lightShaftPass = new LightShaftPass()
			{
				renderPassEvent = RenderPassEvent.AfterRenderingPrePasses
			};
			lightShaftPass.Init(lightShaftMaterial, ditherTex);
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (lightShaftMaterial != null && lightShaftPass != null && renderingData.postProcessingEnabled)
			{
				var settings = VolumeManager.instance.stack.GetComponent<LightShaftPostProcess>();

				if (settings != null && settings.IsActive())
				{
					Shader.EnableKeyword(IDKeys.kLightShaft);
					renderer.EnqueuePass(lightShaftPass);
				}
				else
				{
					Shader.DisableKeyword(IDKeys.kLightShaft);
				}
			}
			else
			{
				Shader.DisableKeyword(IDKeys.kLightShaft);
			}
		}
	}
}