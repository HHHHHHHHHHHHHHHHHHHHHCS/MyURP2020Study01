using UnityEngine;
using static MyGraphics.Scripts.FastPostProcessing.FastPostProcessingFeature;

namespace MyGraphics.Scripts.FastPostProcessing
{
	public class FastPostProcessingVolume : MonoBehaviour
	{
		public bool IsActive => enabled && gameObject.activeInHierarchy && enablePostProcessing;

		public bool enablePostProcessing = true;

		[SerializeField] public FastPostProcessingFeature.MyFastPostProcessingSettings settings = new FastPostProcessingFeature.MyFastPostProcessingSettings();
	}
}