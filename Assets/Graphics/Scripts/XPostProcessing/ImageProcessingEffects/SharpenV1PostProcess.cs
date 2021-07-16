using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessingEffects
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/ImageProcessingEffects/SharpenV1")]
	public class SharpenV1PostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "SharpenV1";

		private static readonly int Strength_ID = Shader.PropertyToID("_Strength");
		private static readonly int Threshold_ID = Shader.PropertyToID("_Threshold");

		public BoolParameter enableEffect = new BoolParameter(false);
		public ClampedFloatParameter strength = new ClampedFloatParameter(0.5f, 0f, 5f);
		public ClampedFloatParameter threshold = new ClampedFloatParameter(0.1f, 0f, 1.0f);

		private void Awake()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public override bool IsActive() => enableEffect.value;

		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT)
		{
			var material = assets.SharpenV1Mat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetFloat(Strength_ID, strength.value);
			material.SetFloat(Threshold_ID, threshold.value);
			// CoreUtils.DrawFullScreen(cmd, material);
			RTHelper.DrawFullScreen(cmd, rtHelper.GetDest(cmd), material);

			swapRT = true;
		}
	}
}