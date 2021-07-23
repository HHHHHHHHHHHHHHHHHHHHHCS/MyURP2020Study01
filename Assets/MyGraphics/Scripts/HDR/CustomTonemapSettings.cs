using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.HDR
{
	[Serializable, VolumeComponentMenu("My/CustomTonemap")]
	public class CustomTonemapSettings : VolumeComponent, IPostProcessComponent
	{
		[Range(-2f, 2f)] public BoolParameter enable = new BoolParameter(false);
		[Range(-2f, 2f)] public FloatParameter exposure = new FloatParameter(0.0f);
		[Range(0f, 2f)] public FloatParameter saturation = new FloatParameter(1.0f);
		[Range(0f, 2f)] public FloatParameter contrast = new FloatParameter(1.0f);

		public bool IsActive() => enable.value;

		public bool IsTileCompatible() => false;
	}
}