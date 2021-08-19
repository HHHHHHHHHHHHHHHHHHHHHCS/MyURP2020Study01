using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.ScreenEffect.MotionLine
{
	public class MotionLinePass : ScriptableRenderPass
	{
		private const string k_tag = "Motion Line";

		private static readonly int src0RT_ID = Shader.PropertyToID("_Src0Tex");
		private static readonly int src1RT_ID = Shader.PropertyToID("_Src1Tex");
		private static readonly int temp0RT_ID = Shader.PropertyToID("_Temp0Tex");

		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private static readonly RenderTargetIdentifier temp0RT_RTI =
			new RenderTargetIdentifier(temp0RT_ID);

		private Material effectMat;

		private RenderTextureDescriptor desc;

		private int pingpongFrame;
		private RenderTexture rtB_0;
		private RenderTexture rtB_1;
		private RenderTexture rtD_0;
		private RenderTexture rtD_1;

		public MotionLinePass(Material mat)
		{
			effectMat = mat;
		}

		public void OnDestroy()
		{
			CoreUtils.Destroy(rtB_0);
			CoreUtils.Destroy(rtB_1);
			CoreUtils.Destroy(rtD_0);
			CoreUtils.Destroy(rtD_1);
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			if (rtB_0 == null)
			{
				pingpongFrame = 0;
				desc = cameraTextureDescriptor;
				desc.msaaSamples = 1;
				desc.depthBufferBits = 0;
				desc.colorFormat = RenderTextureFormat.ARGBHalf;
				desc.memoryless |= RenderTextureMemoryless.Depth;

				rtB_0 = new RenderTexture(desc) {name = "RTB_0"};
				rtB_1 = new RenderTexture(desc) {name = "RTB_1"};
				rtD_0 = new RenderTexture(desc) {name = "RTD_0"};
				rtD_1 = new RenderTexture(desc) {name = "RTD_1"};
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (effectMat == null)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				cmd.GetTemporaryRT(temp0RT_ID, desc);

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//A-----------------------
				cmd.SetGlobalTexture(src0RT_ID, cameraColorTex_RTI);
				cmd.SetRenderTarget(temp0RT_ID, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 0);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				RenderTargetIdentifier input, output;
				//B------------------
				if (pingpongFrame == 1)
				{
					input = rtB_1;
					output = rtB_0;
				}
				else if (pingpongFrame == 2)
				{
					input = rtB_0;
					output = rtB_1;
				}
				else
				{
					input = Texture2D.blackTexture;
					output = rtB_0;
				}

				cmd.SetGlobalTexture(src0RT_ID, temp0RT_RTI);
				cmd.SetGlobalTexture(src1RT_ID, input);
				cmd.SetRenderTarget(output, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 1);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//C------------------------------
				cmd.SetGlobalTexture(src0RT_ID, output);
				cmd.SetRenderTarget(temp0RT_ID, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 2);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//D------------------
				if (pingpongFrame == 1)
				{
					input = rtD_1;
					output = rtD_0;
				}
				else if (pingpongFrame == 2)
				{
					input = rtD_0;
					output = rtD_1;
				}
				else
				{
					input = Texture2D.blackTexture;
					output = rtD_0;
				}

				cmd.SetGlobalTexture(src0RT_ID, temp0RT_RTI);
				cmd.SetGlobalTexture(src1RT_ID, input);
				cmd.SetRenderTarget(output, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 3);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//E--------------------------
				cmd.SetGlobalTexture(src0RT_ID, output);
				cmd.SetRenderTarget(cameraColorTex_RTI, RenderBufferLoadAction.DontCare
					, RenderBufferStoreAction.Store);
				CoreUtils.DrawFullScreen(cmd, effectMat, null, 4);
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				cmd.ReleaseTemporaryRT(temp0RT_ID);
				pingpongFrame = (pingpongFrame % 2) + 1;
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}