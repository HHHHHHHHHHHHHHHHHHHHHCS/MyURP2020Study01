using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/StylizedTonemapFinal")]
	public class StylizedTonemapFinalPostProcess : VolumeComponent, IPostProcessComponent
	{
		public BoolParameter enableEffect = new BoolParameter(false);
		public ClampedFloatParameter exposure = new ClampedFloatParameter(0.0f, -2f, 2f);
		public ClampedFloatParameter saturation = new ClampedFloatParameter(1.0f, 0f, 2f);
		public ClampedFloatParameter contrast = new ClampedFloatParameter(1.0f, 0f, 2f);
		
		public bool IsActive() => enableEffect.value;

		public bool IsTileCompatible() => false;
	}
}