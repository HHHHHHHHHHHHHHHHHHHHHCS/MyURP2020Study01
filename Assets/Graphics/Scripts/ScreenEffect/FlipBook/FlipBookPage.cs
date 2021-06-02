using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	readonly struct FlipBookPage
	{
		#region Allocation/deallocation

		public static FlipBookPage
			Allocate(Mesh mesh, Material material, Vector2Int resolution, int layer)
		{
			var rt = new RenderTexture(resolution.x, resolution.y, 0);

			return new FlipBookPage(rt);
		}

		public static void Deallocate(FlipBookPage page)
			=> Object.Destroy(page._rt);

		#endregion

		#region Public method

		public FlipBookPage StartFlipping(RenderTexture rt, MaterialPropertyBlock mpb,
			float speed)
		{
			mpb.SetFloat("_Speed", speed);
			mpb.SetFloat("_StartTime", Time.time);
			mpb.SetTexture("_ColorMap", rt);
			UnityEngine.Graphics.CopyTexture(rt, _rt);
			return this;
		}

		#endregion

		#region Private members

		private RenderTexture _rt { get; }


		private FlipBookPage(RenderTexture rt)
			=> (_rt) = (rt);

		#endregion
	}
}