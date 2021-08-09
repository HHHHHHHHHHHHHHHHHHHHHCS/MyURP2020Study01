using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Glitch
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Glitch/WaveJitter")]
	public class LineBlockPostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "WaveJitter";

		private static readonly int Params_ID = Shader.PropertyToID("_Params");
		private static readonly int Params2_ID = Shader.PropertyToID("_Params2");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public EnumParameter<Direction> blockDirection = new EnumParameter<Direction>(Direction.Horizontal);
		public EnumParameter<IntervalType> intervalType = new EnumParameter<IntervalType>(IntervalType.Random);
		public ClampedFloatParameter frequency = new ClampedFloatParameter(1f, 0f, 25f);
		public ClampedFloatParameter amount = new ClampedFloatParameter(0.5f, 0f, 1f);
		public ClampedFloatParameter linesWidth = new ClampedFloatParameter(1f, 0.1f, 10f);
		public ClampedFloatParameter speed = new ClampedFloatParameter(0.8f, 0f, 1f);
		public ClampedFloatParameter offset = new ClampedFloatParameter(1f, 0f, 13f);
		public ClampedFloatParameter alpha = new ClampedFloatParameter(1f, 0f, 1f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		private float timeX = 0;
		private int frameCount = 0;
		private float randomFrequency = 0;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.LineBlockMat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			if (intervalType.value == IntervalType.Infinite)
			{
				material.EnableKeyword("USING_FREQUENCY_INFINITE");
			}
			else
			{
				material.DisableKeyword("USING_FREQUENCY_INFINITE");
			}

			if (intervalType.value == IntervalType.Random)
			{
				if (frameCount > frequency.value)
				{
					frameCount = 0;
					randomFrequency = UnityEngine.Random.Range(0, frequency.value);
				}

				frameCount++;
			}


			timeX += Time.deltaTime;
			if (timeX > 100)
			{
				timeX = 0;
			}

			material.SetVector(Params_ID, new Vector4(
				intervalType.value == IntervalType.Random ? randomFrequency : frequency.value,
				timeX * speed.value * 0.2f, amount.value, 0));
			material.SetVector(Params2_ID, new Vector4(offset.value, 1 / linesWidth.value, alpha.value, 0));


			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material,
				(int) blockDirection.value);

			swapRT = true;
		}
	}
}