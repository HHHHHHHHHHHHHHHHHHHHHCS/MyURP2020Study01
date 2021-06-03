using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	public readonly struct FlipBookPage
	{
		private static readonly int Speed = Shader.PropertyToID("_Speed");
		private static readonly int StartTime = Shader.PropertyToID("_StartTime");
		private static readonly int ColorMap = Shader.PropertyToID("_ColorMap");

		#region Allocation/deallocation

		public static FlipBookPage
			Allocate(int w,int h)
		{
			var rt = new RenderTexture(w, h, 0);

			return new FlipBookPage(rt);
		}

		public static void Deallocate(FlipBookPage page)
			=> Object.Destroy(page._rt);

		#endregion

		#region Public method

		public FlipBookPage StartFlipping(RenderTexture rt, MaterialPropertyBlock mpb,
			float speed)
		{
			mpb.SetFloat(Speed, speed);
			mpb.SetFloat(StartTime, Time.time);
			mpb.SetTexture(ColorMap, rt);
			UnityEngine.Graphics.CopyTexture(rt, _rt);
			// CommandBuffer cmd;
			// cmd.CopyTexture();
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