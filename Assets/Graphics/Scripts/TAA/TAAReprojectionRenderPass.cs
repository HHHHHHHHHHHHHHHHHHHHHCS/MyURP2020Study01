using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.TAA
{
	public enum Neighborhood
	{
		MinMax3x3,
		MinMax3x3Rounded,
		MinMax4TapVarying,
	}

	public class TAAReprojectionRenderPass : ScriptableRenderPass
	{
		private const string k_tag = "TAA_Reprojection";

		private const string k_MINMAX_3X3 = "_MINMAX_3X3";
		private const string k_MINMAX_3X3_ROUNDED = "_MINMAX_3X3_ROUNDED";
		private const string k_MINMAX_4TAP_VARYING = "_MINMAX_4TAP_VARYING";
		private const string k_UNJITTER_COLORSAMPLES = "_UNJITTER_COLORSAMPLES";
		private const string k_UNJITTER_NEIGHBORHOOD = "_UNJITTER_NEIGHBORHOOD";
		private const string k_UNJITTER_REPROJECTION = "_UNJITTER_REPROJECTION";
		private const string k_USE_YCOCG = "_USE_YCOCG";
		private const string k_USE_CLIPPING = "_USE_CLIPPING";
		private const string k_USE_DILATION = "_USE_DILATION";
		private const string k_USE_MOTION_BLUR = "_USE_MOTION_BLUR";

		private const string k_USE_MOTION_BLUR_NEIGHBORMAX =
			"_USE_MOTION_BLUR_NEIGHBORMAX";

		private const string k_USE_OPTIMIZATIONS = "_USE_OPTIMIZATIONS";

		// private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");
		// private static readonly int VelocityBuffer_ID = Shader.PropertyToID("_VelocityBuffer");
		// private static readonly int VelocityNeighborMax_ID = Shader.PropertyToID("_VelocityNeighborMax");
		private static readonly int Corner_ID = Shader.PropertyToID("_Corner");
		private static readonly int Jitter_ID = Shader.PropertyToID("_Jitter");
		private static readonly int PrevVP_ID = Shader.PropertyToID("_PrevVP");
		private static readonly int PrevTex_ID = Shader.PropertyToID("_PrevTex");
		private static readonly int FeedbackMin_ID = Shader.PropertyToID("_FeedbackMin");
		private static readonly int FeedbackMax_ID = Shader.PropertyToID("_FeedbackMax");
		private static readonly int MotionScale_ID = Shader.PropertyToID("_MotionScale");

		private static readonly RenderTargetIdentifier CameraColorTexture_ID =
			new RenderTargetIdentifier("_CameraColorTexture");

		private Material material;
		private TAAPostProcess settings;
		private Matrix4x4[] reprojectionMatrix;
		private RenderTexture[] reprojectionBuffer;
		private int reprojectionIndex;
		private float lastTimeScale;

		public TAAReprojectionRenderPass(Material mat)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			material = mat;
			reprojectionMatrix = new Matrix4x4[2];
			reprojectionBuffer = new RenderTexture[2];
			reprojectionIndex = -1;
			lastTimeScale = 1;
		}


		public void Setup(TAAPostProcess _settings)
		{
			settings = _settings;
		}

		public void OnDispose()
		{
			foreach (var item in reprojectionBuffer)
			{
				CoreUtils.Destroy(item);
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			var camera = renderingData.cameraData.camera;
			if (camera.orthographic)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var desc = renderingData.cameraData.cameraTargetDescriptor;
				if (reprojectionBuffer[0] == null || reprojectionBuffer[0].width != desc.width)
				{
					desc.msaaSamples = 1;
					desc.depthBufferBits = 0;
					desc.memoryless |= RenderTextureMemoryless.Depth;
					reprojectionBuffer[0] = new RenderTexture(desc);
					reprojectionBuffer[1] = new RenderTexture(desc);
				}

				var cameraP = camera.GetPerspectiveProjectionQuick();
				var cameraVP = cameraP * camera.worldToCameraMatrix;

				if (reprojectionIndex == -1) // first
				{
					reprojectionIndex = 0;
					reprojectionMatrix[reprojectionIndex] = cameraVP;
					CoreUtils.SetRenderTarget(cmd, reprojectionBuffer[reprojectionIndex]);
					CoreUtils.DrawFullScreen(cmd, material, null, 1);
				}
				else
				{
					CoreUtils.SetKeyword(material, k_MINMAX_3X3, settings.neighborhood.value == Neighborhood.MinMax3x3);
					CoreUtils.SetKeyword(material, k_MINMAX_3X3_ROUNDED,
						settings.neighborhood.value == Neighborhood.MinMax3x3Rounded);
					CoreUtils.SetKeyword(material, k_MINMAX_4TAP_VARYING,
						settings.neighborhood.value == Neighborhood.MinMax4TapVarying);
					CoreUtils.SetKeyword(material, k_UNJITTER_COLORSAMPLES, settings.unjitterColorSamples.value);
					CoreUtils.SetKeyword(material, k_UNJITTER_NEIGHBORHOOD, settings.unjitterNeighborhood.value);
					CoreUtils.SetKeyword(material, k_UNJITTER_REPROJECTION, settings.unjitterReprojection.value);
					CoreUtils.SetKeyword(material, k_USE_YCOCG, settings.useYCoCg.value);
					CoreUtils.SetKeyword(material, k_USE_CLIPPING, settings.useClipping.value);
					CoreUtils.SetKeyword(material, k_USE_DILATION, settings.useDilation.value);
#if UNITY_EDITOR
					CoreUtils.SetKeyword(material, k_USE_MOTION_BLUR,
						Application.isPlaying && settings.useMotionBlur.value);
#else
				CoreUtils.SetKeyword(material, k_USE_MOTION_BLUR, settings.useMotionBlur.value);
#endif
					CoreUtils.SetKeyword(material, k_USE_MOTION_BLUR_NEIGHBORMAX, settings.neighborMaxGen.value);
					CoreUtils.SetKeyword(material, k_USE_OPTIMIZATIONS, settings.useOptimizations.value);


					float oneExtentY = Mathf.Tan(0.5f * Mathf.Deg2Rad * camera.fieldOfView);
					float oneExtentX = oneExtentY * camera.aspect;


					int indexRead = reprojectionIndex;
					int indexWrite = (reprojectionIndex + 1) % 2;

					// cmd.SetGlobalTexture(SrcTex_ID, CameraColorTexture_ID);
					// material.SetTexture(VelocityBuffer_ID, TAAVelocityBufferRenderPass.VelocityBufferTex);
					// material.SetTexture(VelocityNeighborMax_ID, TAAVelocityBufferRenderPass.VelocityNeighborMaxTex);
					material.SetVector(Corner_ID, new Vector4(oneExtentX, oneExtentY, 0f, 0f));
					material.SetVector(Jitter_ID, settings.activeSample);
					material.SetMatrix(PrevVP_ID, reprojectionMatrix[indexRead]);
					material.SetTexture(PrevTex_ID, reprojectionBuffer[indexRead]);
					material.SetFloat(FeedbackMin_ID, settings.feedbackMin.value);
					material.SetFloat(FeedbackMax_ID, settings.feedbackMax.value);
					float timeScale = Time.timeScale == 0 ? lastTimeScale : Time.time;
					lastTimeScale = timeScale;
					material.SetFloat(MotionScale_ID, settings.motionBlurStrength.value *
					                                  (settings.motionBlurIgnoreFF.value
						                                  ? Mathf.Min(1f, 1f / timeScale)
						                                  : 1f));

					
					// reproject frame n-1 into output + history buffer
					CoreUtils.SetRenderTarget(cmd, CameraColorTexture_ID, ClearFlag.None);
					CoreUtils.DrawFullScreen(cmd, material, null, 0);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();
					
					CoreUtils.SetRenderTarget(cmd, reprojectionBuffer[indexWrite], ClearFlag.None);
					CoreUtils.DrawFullScreen(cmd, material, null, 1);

					
					reprojectionMatrix[indexWrite] = cameraVP;
					reprojectionIndex = indexWrite;
				}


				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}