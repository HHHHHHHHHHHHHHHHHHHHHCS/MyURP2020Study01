using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerTrailAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Trail Attr";

		private List<SkinnerTrail> trails;
		private Material mat;

		public SkinnerTrailAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void OnSetup(List<SkinnerTrail> _trails, Material _mat)
		{
			trails = _trails;
			mat = _mat;
		}

		public void OnDestroy()
		{
			trails = null;
			mat = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				foreach (var trail in trails)
				{
					// if (!trail.CanRender)
					// {
					// 	continue;
					// }

					var vertData = trail.Source.Data;

					if (vertData.isFirst)
					{
						continue;
					}

					var data = trail.Data;


					if (data.isFirst)
					{
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosRTI);
						cmd.SetGlobalFloat(RandomSeed_ID, trail.RandomSeed);
					}
					else
					{
						cmd.SetGlobalTexture(SourcePositionTex0_ID, vertData.PrevPosRTI);
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosRTI);
						cmd.SetGlobalFloat(SpeedLimit_ID, trail.SpeedLimit);
					}
					

					if (trail.useMRT)
					{
						if (data.isFirst)
						{
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								TrailKernels.InitializeMRT);
						}
						else
						{
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevRTI(TrailRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevRTI(TrailRTIndex.Velocity));
							cmd.SetGlobalTexture(OrthnormTex_ID, data.PrevRTI(TrailRTIndex.Orthnorm));

							cmd.SetGlobalFloat(Drag_ID, Mathf.Exp(-trail.Drag * Time.deltaTime));
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								TrailKernels.UpdateMRT);
						}
					}
					else
					{
						if (data.isFirst)
						{
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Position), mat,
								TrailKernels.InitializePosition);
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Velocity), mat,
								TrailKernels.InitializeVelocity);
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Orthnorm), mat,
								TrailKernels.InitializeOrthnorm);
						}
						else
						{
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevRTI(TrailRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevRTI(TrailRTIndex.Velocity));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Velocity), mat,
								TrailKernels.UpdateVelocity);

							cmd.SetGlobalTexture(VelocityTex_ID, data.CurrRTI(TrailRTIndex.Velocity));
							cmd.SetGlobalFloat(Drag_ID, Mathf.Exp(-trail.Drag * Time.deltaTime));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Position), mat,
								TrailKernels.UpdatePosition);

							// Invoke the orthonormal update kernel with the updated velocity.
							cmd.SetGlobalTexture(PositionTex_ID, data.CurrRTI(TrailRTIndex.Position));
							cmd.SetGlobalTexture(OrthnormTex_ID, data.PrevRTI(TrailRTIndex.Orthnorm));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrRTI(TrailRTIndex.Orthnorm), mat,
								TrailKernels.UpdateOrthnorm);
						}
					}
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}