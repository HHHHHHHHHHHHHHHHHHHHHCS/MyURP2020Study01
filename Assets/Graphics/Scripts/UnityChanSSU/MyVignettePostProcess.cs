using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/MyVignette")]
	public class MyVignettePostProcess : VolumeComponent, IPostProcessComponent
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