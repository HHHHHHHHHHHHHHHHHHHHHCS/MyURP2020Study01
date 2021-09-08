using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerTrailAttrPass : ScriptableRenderPass
	{
		private class ShaderKernels
		{
			public const int InitializePosition = 0;
			public const int InitializeVelocity = 1;
			public const int InitializeOrthnorm = 2;
			public const int UpdatePosition = 3;
			public const int UpdateVelocity = 4;
			public const int UpdateOrthnorm = 5;
		}

		private class RTIndexs
		{
			public const int Position = 0;
			public const int Velocity = 1;
			public const int Orthnorm = 2;
		}

		private const string k_tag = "Skinner Trail Attr";

		private SkinnerFeature skinnerFeature;
		private SkinnerTrail trail;
		private Material mat;

		private RenderTexture positionTex0;
		private RenderTexture positionTex1;
		private RenderTexture velocityTex0;
		private RenderTexture velocityTex1;
		private RenderTexture orthnormTex0;
		private RenderTexture orthnormTex1;

		private RenderTargetIdentifier[] prevRTIs, currRTIs;

		private bool isFirst;

		public SkinnerTrailAttrPass(SkinnerFeature _skinnerFeature)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			skinnerFeature = _skinnerFeature;
		}

		public void OnSetup(SkinnerTrail _trail, Material _mat)
		{
			trail = _trail;
			mat = _mat;
			OnCreate();
		}

		public void OnCreate()
		{
			int w = SkinnerSource.Instance.Model.VertexCount;
			int h = trail.Template.HistoryLength;

			if (trail.Reconfigured || positionTex0 == null
			                       || positionTex0.width != w
			                       || positionTex0.height != h)
			{
				trail.Reconfigured = false;
				isFirst = true;

				SkinnerUtils.CreateRT(ref positionTex0, w, h, "Trail_" + nameof(positionTex0));
				SkinnerUtils.CreateRT(ref positionTex1, w, h, "Trail_" + nameof(positionTex1));
				SkinnerUtils.CreateRT(ref velocityTex0, w, h, "Trail_" + nameof(velocityTex0));
				SkinnerUtils.CreateRT(ref velocityTex1, w, h, "Trail_" + nameof(velocityTex1));
				SkinnerUtils.CreateRT(ref orthnormTex0, w, h, "Trail_" + nameof(orthnormTex0));
				SkinnerUtils.CreateRT(ref orthnormTex1, w, h, "Trail_" + nameof(orthnormTex1));

				prevRTIs = new RenderTargetIdentifier[3]
				{
					positionTex1,
					velocityTex1,
					orthnormTex1,
				};
				currRTIs = new RenderTargetIdentifier[3]
				{
					positionTex0,
					velocityTex0,
					orthnormTex0,
				};
			}
		}

		public void OnDestroy()
		{
			SkinnerUtils.CleanRT(ref positionTex0);
			SkinnerUtils.CleanRT(ref positionTex1);
			SkinnerUtils.CleanRT(ref velocityTex0);
			SkinnerUtils.CleanRT(ref velocityTex1);
			SkinnerUtils.CleanRT(ref orthnormTex0);
			SkinnerUtils.CleanRT(ref orthnormTex1);
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				CoreUtils.Swap(ref prevRTIs, ref currRTIs);

				if (isFirst)
				{
					isFirst = false;
					mat.SetTexture(SourcePositionTex1_ID,
						skinnerFeature.VertexAttrPass.CurrPosTex);
					mat.SetFloat(RandomSeed_ID, trail.RandomSeed);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Position], mat,
						ShaderKernels.InitializePosition);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Velocity], mat,
						ShaderKernels.InitializeVelocity);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Orthnorm], mat,
						ShaderKernels.InitializeOrthnorm);
				}
				else
				{
					cmd.SetGlobalTexture(SourcePositionTex0_ID, skinnerFeature.VertexAttrPass.PrevPosTex);
					cmd.SetGlobalTexture(SourcePositionTex1_ID, skinnerFeature.VertexAttrPass.CurrPosTex);

					cmd.SetGlobalTexture(PositionTex_ID, prevRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(VelocityTex_ID, prevRTIs[RTIndexs.Velocity]);
					mat.SetFloat(SpeedLimit_ID, trail.SpeedLimit);
					
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Velocity], mat, ShaderKernels.UpdateVelocity);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();

					cmd.SetGlobalTexture(VelocityTex_ID, currRTIs[RTIndexs.Velocity]);
					mat.SetFloat(Drag_ID, Mathf.Exp(-trail.Drag * Time.deltaTime));
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Position], mat, ShaderKernels.UpdatePosition);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();

					// Invoke the orthonormal update kernel with the updated velocity.
					cmd.SetGlobalTexture(PositionTex_ID, currRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(OrthnormTex_ID, prevRTIs[RTIndexs.Orthnorm]);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Orthnorm], mat, ShaderKernels.UpdateOrthnorm);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();
					
					cmd.SetGlobalTexture(TrailPositionTex_ID, currRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(TrailVelocityTex_ID, currRTIs[RTIndexs.Velocity]);
					cmd.SetGlobalTexture(TrailOrthnormTex_ID, currRTIs[RTIndexs.Orthnorm]);
					cmd.SetGlobalTexture(TrailPrevPositionTex_ID, prevRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(TrailPrevVelocityTex_ID, prevRTIs[RTIndexs.Velocity]);
					cmd.SetGlobalTexture(TrailPrevOrthnormTex_ID, prevRTIs[RTIndexs.Orthnorm]);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}