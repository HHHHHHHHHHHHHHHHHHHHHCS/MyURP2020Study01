using UnityEngine;
using static Graphics.Scripts.FastPostProcessing.FastPostProcessingFeature;

namespace Graphics.Scripts.FastPostProcessing
{
	public class FastPostProcessingVolume : MonoBehaviour
	{
		public bool IsActive => enabled && gameObject.activeInHierarchy && enablePostProcessing;

		public bool enablePostProcessing = true;

		[SerializeField] public MyFastPostProcessingSettings settings = new MyFastPostProcessingSettings();
	}
}