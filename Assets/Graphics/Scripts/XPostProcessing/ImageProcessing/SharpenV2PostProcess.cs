using System;
using Graphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessing
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/ImageProcessing/SharpenV2")]
	public class SharpenV2PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "SharpenV2";

		private static readonly int Sharpness_ID = Shader.PropertyToID("_Sharpness");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public ClampedFloatParameter sharpness = new ClampedFloatParameter(0.5f, 0f, 5f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT)
		{
			var material = assets.SharpenV2Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetFloat(Sharpness_ID, sharpness.value);
			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material);

			swapRT = true;
		}
	}
}