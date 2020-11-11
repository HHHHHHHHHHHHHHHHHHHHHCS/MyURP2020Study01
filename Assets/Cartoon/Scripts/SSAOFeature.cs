using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Cartoon.Scripts
{
	//Copy by unity urp ssao
	[DisallowMultipleComponent]
	public class SSAOFeature : ScriptableRendererFeature
	{
		[Serializable]
		public class SSAOSettings
		{
			public enum DepthSource
			{
				Depth = 0,
				DepthNormals = 1,
				//GBuffer = 2,
			}

			public enum NormalQuality
			{
				Low,
				Medium,
				High,
			}

			[SerializeField] public bool downsample = false;

			[SerializeField] public DepthSource source = DepthSource.DepthNormals;

			[SerializeField] public NormalQuality normalSamples = NormalQuality.Medium;

			[SerializeField] public float intensity = 3.0f;

			[SerializeField] public float directLightStrength = 0.25f;

			[SerializeField] public float radius = 0.035f;

			[SerializeField] public int sampleCount = 6;
		}

		// Constants
		private const string c_ShaderName = "Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion";


		[SerializeField, HideInInspector] private Shader shader = null;

		[SerializeField] private SSAOSettings settings = new SSAOSettings();

		private Material material;

		private SSAOPass ssaoPass;

		public override void Create()
		{
			if (ssaoPass == null)
			{
				ssaoPass = new SSAOPass();
			}

			GetMaterial();
			ssaoPass.profilerTag = name;
			ssaoPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (!GetMaterial())
			{
				Debug.LogErrorFormat(
					"{0}.AddRenderPasses(): Missing material. {1} render pass will not be added. Check for missing reference in the renderer resources.",
					GetType().Name, ssaoPass.profilerTag);
				return;
			}

			bool shouldAdd = ssaoPass.Setup(settings);
			if (shouldAdd)
			{
				renderer.EnqueuePass(ssaoPass);
			}
		}

		protected override void Dispose(bool disposing)
		{
			CoreUtils.Destroy(material);
		}

		private bool GetMaterial()
		{
			if (material == null)
			{
				return true;
			}

			if (shader == null)
			{
				shader = Shader.Find(c_ShaderName);
				if (shader == null)
				{
					return false;
				}
			}

			material = CoreUtils.CreateEngineMaterial(shader);
			ssaoPass.material = material;

			return material != null;
		}
	}
}