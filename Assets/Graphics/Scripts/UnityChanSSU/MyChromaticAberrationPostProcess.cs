using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/MyChromaticAberration")]
	public class MyChromaticAberrationPostProcess : VolumeComponent, IPostProcessComponent
	{
		public bool IsActive()
		{
			throw new NotImplementedException();
		}

		public bool IsTileCompatible()
		{
			throw new NotImplementedException();
		}
	}
}