using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public interface ISkinnerSetting
	{
		Material Mat { get; }
		SkinnerSource Source { get; }
		bool UseMRT { get; set; }
		int Width { get; }
		int Height { get; }
		bool Reconfigured { get; }

		SkinnerData Data { get; }

		public bool CanRender { get; }

		void UpdateMat();
	}
}