using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/MyBloom")]
	public class MyBloomPostProcess : VolumeComponent, IPostProcessComponent
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