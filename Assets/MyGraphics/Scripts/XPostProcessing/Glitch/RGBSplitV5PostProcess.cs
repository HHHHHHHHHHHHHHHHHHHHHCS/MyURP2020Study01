using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Glitch
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Glitch/RGBSplitV5")]
	public class RGBSplitV5PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "RGBSplitV5";

		private static readonly int NoiseTex_ID = Shader.PropertyToID("_NoiseTex");
		private static readonly int Params_ID = Shader.PropertyToID("_Params");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public ClampedFloatParameter amplitude = new ClampedFloatParameter(3f, 0f, 5f);
		public ClampedFloatParameter speed = new ClampedFloatParameter(0.1f, 0f, 1f);
		public TextureParameter noiseTex = new TextureParameter(null);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper, CommandBuffer cmd,
			ScriptableRenderContext context,
			ref RenderingData renderingData, out bool swapRT)
		{
			var material = assets.RGBSplitV5Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetVector(Params_ID, new Vector4(amplitude.value, speed.value, 0, 0));
			material.SetTexture(NoiseTex_ID, noiseTex.value != null ? noiseTex.value : Texture2D.grayTexture);

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), rtHelper.GetDest(cmd), material, 0);

			swapRT = true;
		}
	}
}