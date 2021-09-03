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

		private FilteringSettings filteringSettings;
		private RenderStateBlock renderStateBlock;
		private List<ShaderTagId> shaderTagIdList;
		private SortingCriteria sortingCriteria;

		private SkinnerModel skinnerModel;

		private RenderTexture positionTex0;
		private RenderTexture positionTex1;
		private RenderTexture normalTex;
		private RenderTexture tangentTex;

		private RenderTargetIdentifier[] mrt_rti;

		private bool pingpong;

		public RenderTexture CurrPosTex => pingpong ? positionTex1 : positionTex0;
		public RenderTexture PrevPosTex => pingpong ? positionTex0 : positionTex1;


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
			skinnerModel = _model;
			OnCreate();
		}

		public void OnCreate()
		{
			if (positionTex0 == null || positionTex0.width != skinnerModel.VertexCount)
			{
				pingpong = false;

				int w = skinnerModel.VertexCount;
				int h = 1;

				SkinnerUtils.CreateRT(ref positionTex0, w, h, nameof(positionTex0));
				SkinnerUtils.CreateRT(ref positionTex1, w, h, nameof(positionTex1));
				SkinnerUtils.CreateRT(ref normalTex, w, h, nameof(normalTex));
				SkinnerUtils.CreateRT(ref tangentTex, w, h, nameof(tangentTex));

				mrt_rti = new RenderTargetIdentifier[3]
				{
					CurrPosTex,
					normalTex,
					tangentTex,
				};
			}
		}

		public void OnDestroy()
		{
			skinnerModel = null;
			SkinnerUtils.CleanRT(ref positionTex0);
			SkinnerUtils.CleanRT(ref positionTex1);
			SkinnerUtils.CleanRT(ref normalTex);
			SkinnerUtils.CleanRT(ref tangentTex);
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				pingpong = !pingpong;
				mrt_rti[0] = CurrPosTex;
				
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