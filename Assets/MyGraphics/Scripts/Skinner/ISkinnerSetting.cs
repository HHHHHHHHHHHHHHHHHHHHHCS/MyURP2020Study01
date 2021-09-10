using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	public interface ISkinnerSetting
	{
		Material Mat { get; }
		SkinnerSource Source { get; }
		int Width { get; }
		int Height { get; }
		bool Reconfigured { get; }

		SkinnerData Data { get; }

		public bool CanRender { get; }

		void UpdateMat();
	}
}