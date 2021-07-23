using System;
using MyGraphics.Scripts.XPostProcessing.Common;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.XPostProcessing.Vignette
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/Vignette/RapidVignette")]
	public class RapidVignettePostProcess : AbsXPostProcessingParameters
	{
		public enum VignetteType
		{
			ClassicMode = 0,
			ColorMode = 1,
		}

		protected override string k_tag => "RapidVignette";

		private static readonly int VignetteIntensity_ID = Shader.PropertyToID("_VignetteIntensity");
		private static readonly int VignetteCenter_ID = Shader.PropertyToID("_VignetteCenter");
		private static readonly int VignetteColor_ID = Shader.PropertyToID("_VignetteColor");


		public BoolParameter enableEffect = new BoolParameter(false);
		public NoInterpIntParameter priorityQueue = new NoInterpIntParameter(0);

		public EnumParameter<VignetteType> vignetteArea = new EnumParameter<VignetteType>(VignetteType.ClassicMode);
		public ClampedFloatParameter vignetteIntensity = new ClampedFloatParameter(1f, 0.0f, 5.0f);
		public Vector2Parameter vignetteCenter = new Vector2Parameter(new Vector2(0.5f, 0.5f));
		public ColorParameter vignetteColor = new ColorParameter(Color.cyan, true, false, true);

		public override bool IsActive() => enableEffect.value;
		public override int PriorityQueue() => priorityQueue.value;
		public override bool IsTileCompatible() => false;

		public override void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT)
		{
			var material = assets.rapidVignetteMat;
			if (material == null)
			{
				swapRT = false;
				return;
			}

			material.SetFloat(VignetteIntensity_ID, vignetteIntensity.value);
			material.SetVector(VignetteCenter_ID, vignetteCenter.value);
			if (vignetteArea.value == VignetteType.ColorMode)
			{
				material.SetColor(VignetteColor_ID, vignetteColor.value);
			}
			RTHelper.DrawFullScreen(cmd, rtHelper.GetSrc(cmd), material, (int) vignetteArea.value);

			swapRT = false;
		}
	}
}