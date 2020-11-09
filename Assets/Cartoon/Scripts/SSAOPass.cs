using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Cartoon.Scripts
{
	public class SSAOPass : ScriptableRenderPass
	{
		private enum ShaderPasses
		{
			AO = 0,
			BlurHorizontal = 1,
			BlurVertical = 2,
			BlurFinal = 3,
		}

		// Constants
		private const string c_SSAOAmbientOcclusionParamName = "_AmbientOcclusionParam";
		private const string c_SSAOTextureName = "_ScreenSpaceOcclusionTexture";

		// Statics
		private static readonly int s_BaseMapID = Shader.PropertyToID("_BaseMap");
		private static readonly int s_ScaleBiasID = Shader.PropertyToID("_ScaleBiasRt");
		private static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");
		private static readonly int s_SSAOTexture1ID = Shader.PropertyToID("_SSAO_OcclusionTexture1");
		private static readonly int s_SSAOTexture2ID = Shader.PropertyToID("_SSAO_OcclusionTexture2");
		private static readonly int s_SSAOTexture3ID = Shader.PropertyToID("_SSAO_OcclusionTexture3");

		public string profilerTag;

		public Material material;

		private SSAOFeature.SSAOSettings currentSettings;

		private ProfilingSampler profilingSampler = new ProfilingSampler("SSAO.Execute()");

		private RenderTextureDescriptor m_Descriptor;

		private RenderTargetIdentifier ssaoTextureTarget1 =
			new RenderTargetIdentifier(s_SSAOTexture1ID, 0, CubemapFace.Unknown, -1);

		private RenderTargetIdentifier ssaoTextureTarget2 =
			new RenderTargetIdentifier(s_SSAOTexture2ID, 0, CubemapFace.Unknown, -1);

		private RenderTargetIdentifier ssaoTextureTarget3 =
			new RenderTargetIdentifier(s_SSAOTexture3ID, 0, CubemapFace.Unknown, -1);


		public bool Setup(SSAOFeature.SSAOSettings settings)
		{
			currentSettings = settings;
			switch (currentSettings.source)
			{
				case SSAOFeature.SSAOSettings.DepthSource.Depth:
					ConfigureInput(ScriptableRenderPassInput.Depth);
					break;
				case SSAOFeature.SSAOSettings.DepthSource.DepthNormals:
					ConfigureInput(ScriptableRenderPassInput.Normal);
					break;
				default:
					throw new ArgumentOutOfRangeException();
			}

			return material != null
			       && currentSettings.intensity > 0.0f
			       && currentSettings.radius > 0.0f
			       && currentSettings.sampleCount > 0;
		}
		
		
		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			throw new System.NotImplementedException();
		}


	}
}