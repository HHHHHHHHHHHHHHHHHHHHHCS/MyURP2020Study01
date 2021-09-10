using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerVertexAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Vertex Attr";

		// private FilteringSettings filteringSettings;
		// private RenderStateBlock renderStateBlock;
		// private List<ShaderTagId> shaderTagIdList;
		// private SortingCriteria sortingCriteria;

		private List<SkinnerSource> sources;


		public SkinnerVertexAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);

			// sortingCriteria = SortingCriteria.CommonOpaque;
			// shaderTagIdList = new List<ShaderTagId>
			// {
			// 	new ShaderTagId("SkinnerSource")
			// };
			// filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
			// renderStateBlock = new RenderStateBlock();
		}

		public void OnSetup(List<SkinnerSource> _sources)
		{
			sources = _sources;
		}

		public void OnDestroy()
		{
			sources = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				//因为物体经常显示隐藏所以 RT宽高不一致
				//所以改成多轮渲染
				/*
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
				*/

				foreach (var source in sources)
				{
					var data = source.Data;
					var rts = data.CurrRTS;
					cmd.SetRenderTarget(rts, rts[0]);
					cmd.DrawRenderer(data.smr, data.mat);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		public override void OnFinishCameraStackRendering(CommandBuffer cmd)
		{
			if (!SkinnerManager.CheckInstance())
			{
				return;
			}

			SkinnerManager.Instance.AfterRendering();
		}
	}
}