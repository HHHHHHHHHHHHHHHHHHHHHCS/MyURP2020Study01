using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect
{

	[Serializable, VolumeComponentMenu("My/ScreenEffect")]
	public class ScreenEffectPostProcess : VolumeComponent, IPostProcessComponent
	{
		public BoolParameter enableEffect = new BoolParameter(false);

		public bool IsActive() => enableEffect.value;

		public bool IsTileCompatible() => false;
		
	}
}