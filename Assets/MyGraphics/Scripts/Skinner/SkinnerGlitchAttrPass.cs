using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerGlitchAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Glitch Attr";

		private List<SkinnerGlitch> glitches;
		private Material mat;

		public SkinnerGlitchAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void OnSetup(List<SkinnerGlitch> _glitches, Material _mat)
		{
			glitches = _glitches;
			mat = _mat;
		}

		public void OnDestroy()
		{
			glitches = null;
			mat = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				foreach (var glitch in glitches)
				{
					// if (!particle.CanRender)
					// {
					// 	continue;
					// }

					var vertData = glitch.Source.Data;

					if (vertData.isFirst)
					{
						continue;
					}

					var data = glitch.Data;

					if (data.isFirst)
					{
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
						cmd.SetGlobalFloat(RandomSeed_ID, glitch.RandomSeed);
					}
					else
					{
						cmd.SetGlobalFloat(VelocityScale_ID, glitch.VelocityScale);
						cmd.SetGlobalTexture(SourcePositionTex0_ID, vertData.PrevPosTex);
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
					}

					if (glitch.useMRT)
					{
						if (data.isFirst)
						{
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								GlitchKernels.InitializeMRT);
						}
						else
						{
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevTex(GlitchRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevTex(GlitchRTIndex.Velocity));
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								GlitchKernels.UpdateMRT);
						}
					}
					else
					{
						if (data.isFirst)
						{
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(GlitchRTIndex.Position), mat,
								GlitchKernels.InitializePosition);
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(GlitchRTIndex.Velocity), mat,
								GlitchKernels.InitializeVelocity);
						}
						else
						{
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevTex(GlitchRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevTex(GlitchRTIndex.Velocity));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(GlitchRTIndex.Position), mat,
								GlitchKernels.UpdatePosition);

							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(GlitchRTIndex.Velocity), mat,
								GlitchKernels.UpdateVelocity);
						}
					}
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}