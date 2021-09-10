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
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
						cmd.SetGlobalFloat(RandomSeed_ID, trail.RandomSeed);
						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Position), mat,
							TrailKernels.InitializePosition);
						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Velocity), mat,
							TrailKernels.InitializeVelocity);
						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Orthnorm), mat,
							TrailKernels.InitializeOrthnorm);
					}
					else
					{
						cmd.SetGlobalFloat(RandomSeed_ID, trail.RandomSeed);

						cmd.SetGlobalTexture(SourcePositionTex0_ID, vertData.PrevPosTex);
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);

						cmd.SetGlobalTexture(PositionTex_ID, data.PrevTex(TrailRTIndex.Position));
						cmd.SetGlobalTexture(VelocityTex_ID, data.PrevTex(TrailRTIndex.Velocity));
						cmd.SetGlobalFloat(SpeedLimit_ID, trail.SpeedLimit);

						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Velocity), mat,
							TrailKernels.UpdateVelocity);

						context.ExecuteCommandBuffer(cmd);
						cmd.Clear();

						cmd.SetGlobalTexture(VelocityTex_ID, data.CurrTex(TrailRTIndex.Velocity));
						cmd.SetGlobalFloat(Drag_ID, Mathf.Exp(-trail.Drag * Time.deltaTime));
						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Position), mat,
							TrailKernels.UpdatePosition);

						context.ExecuteCommandBuffer(cmd);
						cmd.Clear();

						// Invoke the orthonormal update kernel with the updated velocity.
						cmd.SetGlobalTexture(PositionTex_ID, data.CurrTex(TrailRTIndex.Position));
						cmd.SetGlobalTexture(OrthnormTex_ID, data.PrevTex(TrailRTIndex.Orthnorm));
						SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(TrailRTIndex.Orthnorm), mat,
							TrailKernels.UpdateOrthnorm);

						context.ExecuteCommandBuffer(cmd);
						cmd.Clear();
					}
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}