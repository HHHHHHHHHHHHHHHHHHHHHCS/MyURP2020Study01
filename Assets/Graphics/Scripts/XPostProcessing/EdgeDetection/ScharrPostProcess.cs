using System;
using Graphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.EdgeDetection
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/EdgeDetection/Scharr")]
	public class ScharrPostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "EdgeDetection";

		private static readonly int Params_ID = Shader.PropertyToID("_Params");
		private static readonly int EdgeColor_ID = Shader.PropertyToID("_EdgeColor");
		private static readonly int BackgroundColor_ID = Shader.PropertyToID("_BackgroundColor");


		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);
		[Header("Edge Property")] public ClampedFloatParameter edgeWidth = new ClampedFloatParameter(0.3f, 0.05f, 5f);
		public ColorParameter edgeColor = new ColorParameter(Color.black, true, false, true);

		[Header("Background Property")]
		public ClampedFloatParameter backgroundFade = new ClampedFloatParameter(1f, 0f, 1f);

		public ColorParameter backgroundColor = new ColorParameter(Color.white, true, false, true);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.ScharrMat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetVector(Params_ID, new Vector4(edgeWidth.value, backgroundFade.value, 0, 0));
			material.SetColor(EdgeColor_ID, edgeColor.value);
			material.SetColor(BackgroundColor_ID, backgroundColor.value);

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material, 0);

			swapRT = true;
		}
	}
}