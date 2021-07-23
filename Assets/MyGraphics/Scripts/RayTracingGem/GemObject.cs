using UnityEngine;

namespace MyGraphics.Scripts.RayTracingGem
{
	[RequireComponent(typeof(MeshRenderer),typeof(MeshFilter))]
	public class GemObject : MonoBehaviour
	{
		private void OnEnable()
		{
			GemManager.Instance.RegisterGem(this);
		}
    
		private void OnDisable()
		{
			GemManager.Instance.UnregisterGem(this);
		}
	}
}
