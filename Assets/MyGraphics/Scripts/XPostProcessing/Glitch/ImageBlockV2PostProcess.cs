using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Glitch
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Glitch/ImageBlockV2")]
	public class ImageBlockV2PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "ImageBlockV2";

		private static readonly int Params_ID = Shader.PropertyToID("_Params");
		private static readonly int Params2_ID = Shader.PropertyToID("_Params2");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		[Header("Core Property")] public ClampedFloatParameter fade = new ClampedFloatParameter(1f, 0f, 1f);
		public ClampedFloatParameter speed = new ClampedFloatParameter(0.5f, 0f, 1f);
		public ClampedFloatParameter amount = new ClampedFloatParameter(1f, 0f, 10f);

		[Header("Block Noise Size")]
		public ClampedFloatParameter blockLayer1_U = new ClampedFloatParameter(2f, 0f, 50f);

		public ClampedFloatParameter blockLayer1_V = new ClampedFloatParameter(16f, 0f, 50f);

		[Header("Block Intensity")]
		public ClampedFloatParameter blockLayer1_Intensity = new ClampedFloatParameter(8f, 0f, 50f);

		public ClampedFloatParameter rgbSplitIntensity = new ClampedFloatParameter(2f, 0f, 50f);

		[Header("Block Visualize Debug")] public BoolParameter blockVisualizeDebug = new BoolParameter(false);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		private float timer;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.ImageBlockV2Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			timer += Time.deltaTime;
			if (timer > 100f)
			{
				timer -= 100f;
			}

			material.SetVector(Params_ID, new Vector4(timer * speed.value, amount.value, fade.value, 0.0f));
			material.SetVector(Params2_ID, new Vector4(blockLayer1_U.value, blockLayer1_V.value,
				blockLayer1_Intensity.value, rgbSplitIntensity.value));

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material,
				blockVisualizeDebug.value ? 1 : 0);

			swapRT = true;
		}
	}
}