using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.Vignette
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Vignette/AuroraVignette")]
	public class AuroraVignettePostProcess : AbsXPostProcessingParameters
	{
		protected override string k_tag => "AuroraVignette";

		private static readonly int VignetteArea_ID = Shader.PropertyToID("_VignetteArea");
		private static readonly int VignetteSmothness_ID = Shader.PropertyToID("_VignetteSmothness");
		private static readonly int ColorChange_ID = Shader.PropertyToID("_ColorChange");
		private static readonly int ColorFactor_ID = Shader.PropertyToID("_ColorFactor");
		private static readonly int TimeX_ID = Shader.PropertyToID("_TimeX");
		private static readonly int VignetteFading_ID = Shader.PropertyToID("_Fading");

		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public ClampedFloatParameter vignetteArea = new ClampedFloatParameter(0.8f, 0.0f, 1.0f);
		public ClampedFloatParameter vignetteSmothness = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
		public ClampedFloatParameter vignetteFading = new ClampedFloatParameter(1f, 0f, 1f);
		public ClampedFloatParameter colorChange = new ClampedFloatParameter(0.1f, 0.1f, 1.0f);
		public ColorParameter colorFactor = new ColorParameter(Color.white, true, false, true);
		public ClampedFloatParameter flowSpeed = new ClampedFloatParameter(1f, -2, 2f);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		private float timer = 0;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT)
		{
			var material = assets.AuroraVignetteMat;
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

			material.SetFloat(VignetteArea_ID, vignetteArea.value);
			material.SetFloat(VignetteSmothness_ID, vignetteSmothness.value);
			material.SetFloat(ColorChange_ID, colorChange.value * 10f);
			material.SetColor(ColorFactor_ID, colorFactor.value);
			material.SetFloat(TimeX_ID, timer * flowSpeed.value);
			material.SetFloat(VignetteFading_ID, vignetteFading.value);

			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), material);

			swapRT = false;
		}
	}
}