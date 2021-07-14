using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.ImageProcessingEffects
{
	[Serializable, VolumeComponentMenu("My/XPostProcessing/ImageProcessingEffects/SharpenV1")]
	public class SharpenV1PostProcess : VolumeComponent, IPostProcessComponent
	{
		public BoolParameter enableEffect = new BoolParameter(false);
		public ClampedFloatParameter strength = new ClampedFloatParameter(0.5f, 0f, 5f);
		public ClampedFloatParameter threshold = new ClampedFloatParameter(0.1f, 0f, 1.0f);

		public bool IsActive() => enableEffect.value;

		public bool IsTileCompatible() => false;
	}
}