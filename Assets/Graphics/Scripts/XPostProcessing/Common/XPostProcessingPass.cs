using System;
using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.Common
{
	public class XPostProcessingPass : ScriptableRenderPass
	{
		private const string k_tag = "XPostProcess";

		private readonly XPostProcessAssets assets;
		private readonly Type[] absXPostProcessingParameters;
		private readonly RTHelper rtHelper;

		public XPostProcessingPass(XPostProcessAssets _assets)
		{
			assets = _assets;
			profilingSampler = new ProfilingSampler(k_tag);
			absXPostProcessingParameters = CoreUtils.GetAllTypesDerivedFrom<AbsXPostProcessingParameters>()
				.Where(t => !t.IsAbstract).ToArray();
			rtHelper = new RTHelper();
		}


		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			var desc = renderingData.cameraData.cameraTargetDescriptor;
			rtHelper.SetupTempRT(desc);
		}

		public override void OnCameraCleanup(CommandBuffer cmd)
		{
			rtHelper.ReleaseTempRT(cmd);
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var effects = absXPostProcessingParameters
					.Select(t => (AbsXPostProcessingParameters) VolumeManager.instance.stack.GetComponent(t))
					.Where(cls => cls.IsActive())
					.OrderBy(cls => cls.PriorityQueue());

				foreach (var item in effects)
				{

					using (new ProfilingScope(cmd, item.profilingSampler))
					{
						item.Execute(assets, rtHelper, cmd, context, ref renderingData, out var swapRT);

						if (swapRT)
						{
							rtHelper.SwapRT();
						}

						context.ExecuteCommandBuffer(cmd);
						cmd.Clear();
					}
				}

				if (!rtHelper.SrcIsFinal(cmd))
				{
					RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), RTHelper.Final_RTI, assets.BlitMat);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}