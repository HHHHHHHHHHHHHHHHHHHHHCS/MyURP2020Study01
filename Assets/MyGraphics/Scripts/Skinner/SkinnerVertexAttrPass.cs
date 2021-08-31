using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerVertexAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Vertex Attr";

		private FilteringSettings filteringSettings;
		private RenderStateBlock renderStateBlock;
		private List<ShaderTagId> shaderTagIdList;
		private SortingCriteria sortingCriteria;

		private SkinnerModel model;

		private RenderTexture positionTex0;
		private RenderTexture positionTex1;
		private RenderTexture normalTex;
		private RenderTexture tangentTex;

		private RenderTargetIdentifier[] mrt_rti;

		private bool pingpong;

		public SkinnerVertexAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);

			sortingCriteria = SortingCriteria.CommonOpaque;
			shaderTagIdList = new List<ShaderTagId>
			{
				new ShaderTagId("SkinnerSource")
			};

			filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
			renderStateBlock = new RenderStateBlock();
		}

		public void OnSetup(SkinnerModel _model)
		{
			model = _model;
			OnCreate();

			if (pingpong)
			{
				mrt_rti[0] = positionTex1;
			}
			else
			{
				mrt_rti[0] = positionTex0;
			}

			pingpong = !pingpong;
		}

		public void OnCreate()
		{
			if (EnsureRT(ref positionTex0))
			{
				EnsureRT(ref positionTex1);
				EnsureRT(ref normalTex);
				EnsureRT(ref tangentTex);

				positionTex0.name = nameof(positionTex0);
				positionTex1.name = nameof(positionTex1);
				normalTex.name = nameof(normalTex);
				tangentTex.name = nameof(tangentTex);

				pingpong = true;
				mrt_rti = new RenderTargetIdentifier[3]
				{
					positionTex1,
					normalTex,
					tangentTex,
				};
			}
		}

		public void OnDestroy()
		{
			model = null;
			CleanRT(ref positionTex0);
			CleanRT(ref positionTex1);
			CleanRT(ref normalTex);
			CleanRT(ref tangentTex);
		}

		private bool EnsureRT(ref RenderTexture rt)
		{
			if (rt == null || rt.width != model.VertexCount)
			{
				CleanRT(ref rt);
				rt = new RenderTexture(model.VertexCount, 1, 0, RenderTextureFormat.ARGBFloat);
				return true;
			}

			return false;
		}

		private void CleanRT(ref RenderTexture rt)
		{
			CoreUtils.Destroy(rt);
			rt = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.SetRenderTarget(mrt_rti, mrt_rti[0]);

				// cmd.SetRenderTarget(positionTex0);

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//XR如果不方便MRT, 则可以用SetRT 然后cmd.draw
				//built-in可以用camera.RenderWithShader
				var drawingSettings =
					CreateDrawingSettings(shaderTagIdList, ref renderingData, sortingCriteria);
				context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings,
					ref renderStateBlock);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}