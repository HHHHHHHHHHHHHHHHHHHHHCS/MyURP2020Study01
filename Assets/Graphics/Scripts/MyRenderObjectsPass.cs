using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static RoyaleBattle.MyRenderObjectsFeature;

namespace RoyaleBattle
{
	public class MyRenderObjectsPass : ScriptableRenderPass
	{
		private RenderQueueType renderQueueType;
		private FilteringSettings filteringSettings;
		private CustomCameraSettings cameraSettings;
		private string profilerTag;
		private ProfilingSampler profilingSampler;
		private RenderStateBlock renderStateBlock;

		private List<ShaderTagId> shaderTagIdList = new List<ShaderTagId>();


		public Material overrideMaterial { get; set; }
		public int overrideMaterialPassIndex { get; set; }


		public MyRenderObjectsPass(RenderObjectsSettings settings)
		{
			var filterSettings = settings.filterSettings;

			profilerTag = settings.passTag;
			profilingSampler = new ProfilingSampler(profilerTag);
			renderPassEvent = settings.renderPassEvent;
			renderQueueType = filterSettings.renderQueueType;
			overrideMaterial = null;
			overrideMaterialPassIndex = 0;
			RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
				? RenderQueueRange.transparent
				: RenderQueueRange.opaque;
			filteringSettings = new FilteringSettings(renderQueueRange, filterSettings.layerMask,
				(uint)Mathf.Pow(2, filterSettings.renderingLayerMask));

			var shaderTags = filterSettings.shaderTags;
			if (shaderTags != null && shaderTags.Length > 0)
			{
				foreach (var tag in shaderTags)
				{
					shaderTagIdList.Add(new ShaderTagId(tag));
				}
			}
			else
			{
				shaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
				shaderTagIdList.Add(new ShaderTagId("UniversalForward"));
				shaderTagIdList.Add(new ShaderTagId("LightweightForward"));
			}

			renderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
			cameraSettings = settings.cameraSettings;
		}

		public void SetDepthState(bool writeEnabled, CompareFunction function = CompareFunction.Less)
		{
			renderStateBlock.mask |= RenderStateMask.Depth;
			renderStateBlock.depthState = new DepthState(writeEnabled, function);
		}

		public void SetStencilState(int reference, CompareFunction compareFunction, StencilOp passOp, StencilOp failOp,
			StencilOp zFailOp)
		{
			StencilState stencilState = StencilState.defaultValue;
			stencilState.enabled = true;
			stencilState.SetCompareFunction(compareFunction);
			stencilState.SetPassOperation(passOp);
			stencilState.SetFailOperation(failOp);
			stencilState.SetZFailOperation(zFailOp);

			renderStateBlock.mask |= RenderStateMask.Stencil;
			renderStateBlock.stencilReference = reference;
			renderStateBlock.stencilState = stencilState;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
				? SortingCriteria.CommonTransparent
				: renderingData.cameraData.defaultOpaqueSortFlags;

			DrawingSettings drawingSettings =
				CreateDrawingSettings(shaderTagIdList, ref renderingData, sortingCriteria);
			drawingSettings.overrideMaterial = overrideMaterial;
			drawingSettings.overrideMaterialPassIndex = overrideMaterialPassIndex;

			ref CameraData cameraData = ref renderingData.cameraData;
			Camera camera = cameraData.camera;
			float cameraAspect = camera.aspect;


			CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				if (cameraSettings.overrideCamera && cameraData.isStereoEnabled)
				{
					Debug.LogWarning(
						"RenderObjects pass is configured to override camera matrices. While rendering in stereo camera matrices cannot be overriden.");
				}

				if (cameraSettings.overrideCamera && !cameraData.isStereoEnabled)
				{
					Matrix4x4 projectionMatrix = Matrix4x4.Perspective(cameraSettings.cameraFieldOfView, cameraAspect,
						camera.nearClipPlane, camera.farClipPlane);


					projectionMatrix =
						GL.GetGPUProjectionMatrix(projectionMatrix, cameraData.IsCameraProjectionMatrixFlipped());

					Matrix4x4 viewMatrix = cameraData.GetViewMatrix();
					Vector4 cameraTranslation = viewMatrix.GetColumn(3);
					viewMatrix.SetColumn(3, cameraTranslation + cameraSettings.offset);

					RenderingUtils.SetViewAndProjectionMatrices(cmd, viewMatrix, projectionMatrix, false);
				}

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings,
					ref renderStateBlock);

				if (cameraSettings.overrideCamera && cameraSettings.restoreCamera && !cameraData.isStereoEnabled)
				{
					RenderingUtils.SetViewAndProjectionMatrices(cmd, cameraData.GetViewMatrix(),
						cameraData.GetGPUProjectionMatrix(), false);
				}

				context.ExecuteCommandBuffer(cmd);
				CommandBufferPool.Release(cmd);
			}
		}
	}
}