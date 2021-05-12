using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.AtmosphericScattering
{
	public class LightShaftPass : ScriptableRenderPass
	{
		private const string k_tag = "LightShaft";

		private static readonly int DitheringTex_ID = Shader.PropertyToID("_DitheringTex");
		private static readonly int LightShaft_ID = Shader.PropertyToID("_LightShaft");
		private static readonly RenderTargetIdentifier lightShaft_RTI = new RenderTargetIdentifier(LightShaft_ID);

		private ProfilingSampler profilingSampler;
		private Material mat;

		public void Init(Material lightShaftMaterial, Texture2D ditherTex)
		{
			lightShaftMaterial.SetTexture(DitheringTex_ID, ditherTex);
			mat = lightShaftMaterial;
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			cmd.GetTemporaryRT(LightShaft_ID, cameraTextureDescriptor.width, cameraTextureDescriptor.height, 0,
				FilterMode.Bilinear, RenderTextureFormat.R8);
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			cmd.ReleaseTemporaryRT(LightShaft_ID);
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				//需要四个顶点 所以用blit
				cmd.Blit(null, lightShaft_RTI, mat, 0);
				cmd.SetGlobalTexture("_LightShaft", lightShaft_RTI);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}