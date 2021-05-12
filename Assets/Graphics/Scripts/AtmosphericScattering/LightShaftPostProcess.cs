using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.AtmosphericScattering
{
	[Serializable, VolumeComponentMenu("My/Scattering-LightShaft")]
	public class LightShaftPostProcess : VolumeComponent, IPostProcessComponent
	{
		public BoolParameter enableEffect = new BoolParameter(false);

		public bool IsActive() => enableEffect.value;

		public bool IsTileCompatible() => false;
	}
}