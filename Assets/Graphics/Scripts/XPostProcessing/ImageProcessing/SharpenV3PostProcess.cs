using System;
using Graphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessing
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/ImageProcessing/SharpenV3")]
	public class SharpenV3PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "SharpenV3";

		private static readonly int CentralFactor_ID = Shader.PropertyToID("_CentralFactor");
		private static readonly int SideFactor_ID = Shader.PropertyToID("_SideFactor");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);
		
		public ClampedFloatParameter sharpness = new ClampedFloatParameter(0.5f, 0f, 1f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT)
		{
			var material = assets.SharpenV3Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetFloat(CentralFactor_ID, 1.0f + (3.2f * sharpness.value));
			material.SetFloat(SideFactor_ID, 0.8f * sharpness.value);

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material);

			swapRT = true;
		}
	}
}