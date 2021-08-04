using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Glitch
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Glitch/WaveJitter")]
	public class WaveJitterPostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "WaveJitter";

		private static readonly int Params_ID = Shader.PropertyToID("_Params");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public EnumParameter<Direction> jitterDirection = new EnumParameter<Direction>(Direction.Horizontal);
		public EnumParameter<IntervalType> intervalType = new EnumParameter<IntervalType>(IntervalType.Random);
		public ClampedFloatParameter frequency = new ClampedFloatParameter(5f, 0f, 50f);
		public ClampedFloatParameter rgbSplit = new ClampedFloatParameter(20f, 0f, 50f);
		public ClampedFloatParameter speed = new ClampedFloatParameter(0.25f, 0f, 1f);
		public ClampedFloatParameter amount = new ClampedFloatParameter(1f, 0f, 2f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.WaveJitterMat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			Vector4 v4 = new Vector4(frequency.value, rgbSplit.value, speed.value, amount.value);

			if (intervalType.value == IntervalType.Random)
			{
				v4.x = UnityEngine.Random.Range(0, frequency.value);
			}

			if (intervalType.value == IntervalType.Infinite)
			{
				material.EnableKeyword("USING_FREQUENCY_INFINITE");
			}
			else
			{
				material.DisableKeyword("USING_FREQUENCY_INFINITE");
			}

			material.SetVector(Params_ID, v4);

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material,
				(int) jitterDirection.value);

			swapRT = true;
		}
	}
}