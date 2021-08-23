using System;
using UnityEngine;

namespace MyGraphics.Scripts.GPUOcclusionCulling
{
	public class HardwareOcclusionManager : MonoBehaviour
	{
		private HardwareOcclusion hardwareOcclusion;
		private bool state = true;

		private void Start()
		{
			hardwareOcclusion = GetComponent<HardwareOcclusion>();
		}

		private void OnApplicationFocus(bool hasFocus)
		{
			if (state != hasFocus && hardwareOcclusion)
			{
				hardwareOcclusion.enabled = hasFocus;
				state = hasFocus;
			}
		}
	}
}