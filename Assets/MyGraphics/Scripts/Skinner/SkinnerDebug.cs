using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class SkinnerDebug : MonoBehaviour, ISkinnerSetting
	{
		[SerializeField] private SkinnerSource source;

		private SkinnerData data;

		public Material Mat => null;
		public SkinnerSource Source => source;
		public bool UseMRT => false;
		public bool Reconfigured => false;
		public SkinnerData Data => data;
		public bool CanRender => source != null && source.CanRender;

		public int Width => 0;
		public int Height => 0;

		private void OnEnable()
		{
			if (!CanRender)
			{
				return;
			}

			data = new SkinnerData();
			SkinnerManager.Instance.Register(this);
		}

		private void OnDisable()
		{
			SkinnerManager.Instance.Remove(this);
		}

		public void UpdateMat()
		{
		}
	}
}