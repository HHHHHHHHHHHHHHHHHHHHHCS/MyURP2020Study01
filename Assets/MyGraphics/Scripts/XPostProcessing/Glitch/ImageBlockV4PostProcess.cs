using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Glitch
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Glitch/ImageBlockV4")]
	public class ImageBlockV4PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "ImageBlockV4";

		private static readonly int Params_ID = Shader.PropertyToID("_Params");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public ClampedFloatParameter speed = new ClampedFloatParameter(10f, 0f, 50f);
		public ClampedFloatParameter blockSize = new ClampedFloatParameter(8f, 0f, 50f);
		public ClampedFloatParameter maxRGBSplitX = new ClampedFloatParameter(1f, 0f, 25f);
		public ClampedFloatParameter maxRGBSplitY = new ClampedFloatParameter(1f, 0f, 25f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.ImageBlockV4Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetVector(Params_ID,
				new Vector4(speed.value, blockSize.value, maxRGBSplitX.value, maxRGBSplitY.value));


			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material, 0);

			swapRT = true;
		}
	}
}