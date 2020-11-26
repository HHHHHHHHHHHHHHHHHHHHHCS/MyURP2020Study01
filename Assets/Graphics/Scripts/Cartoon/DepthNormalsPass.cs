using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.Cartoon
{
	public class DepthNormalsPass : ScriptableRenderPass
	{
		private const string c_My_Depth_Normal_ID = "MY_DEPTH_NORMAL";

		private RenderTargetHandle destination { get; set; }
		private Material depthNormalsMaterial;
		private FilteringSettings filteringSettings;
		private ShaderTagId shaderTagId;

		public DepthNormalsPass(RenderQueueRange range, LayerMask layerMask, Material _depthNormalsMaterial)
		{
			filteringSettings = new FilteringSettings(range, layerMask);
			depthNormalsMaterial = _depthNormalsMaterial;
			shaderTagId = new ShaderTagId("DepthNormals");
		}

		public void Setup(RenderTargetHandle dest)
		{
			destination = dest;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			RenderTextureDescriptor descriptor = cameraTextureDescriptor;
			descriptor.depthBufferBits = 32;
			descriptor.colorFormat = RenderTextureFormat.ARGB32;

			cmd.GetTemporaryRT(destination.id, descriptor, FilterMode.Point);
			ConfigureTarget(destination.Identifier());
			ConfigureClear(ClearFlag.All, Color.black);
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			if (cmd == null)
			{
				throw new ArgumentNullException("cmd");
			}

			CoreUtils.SetKeyword(cmd, c_My_Depth_Normal_ID, false);
			
			if (destination != RenderTargetHandle.CameraTarget)
			{
				cmd.ReleaseTemporaryRT(destination.id);
				destination = RenderTargetHandle.CameraTarget;
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get("DepthNormals Prepass");

			using (new ProfilingSample(cmd, "DpethNormals Prepass"))
			{
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
				var drawSettings = CreateDrawingSettings(shaderTagId, ref renderingData, sortFlags);
				drawSettings.perObjectData = PerObjectData.None; //这里只需要法线  所以不用准备什么别的渲染数据


				ref CameraData cameraData = ref renderingData.cameraData;
				Camera camera = cameraData.camera;
				if (cameraData.camera.stereoEnabled) //cameraData.isStereoEnabled
				{
					context.StartMultiEye(camera);
				}

				drawSettings.overrideMaterial = depthNormalsMaterial;

				context.DrawRenderers(renderingData.cullResults, ref drawSettings,
					ref filteringSettings);

				cmd.SetGlobalTexture("_CameraDepthNormalsTexture", destination.id);
				CoreUtils.SetKeyword(cmd, c_My_Depth_Normal_ID, true);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();
		}
	}
}