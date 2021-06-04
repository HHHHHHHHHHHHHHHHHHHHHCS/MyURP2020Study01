using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	public class FlipBookPage
	{
		private static readonly int Speed_ID = Shader.PropertyToID("_Speed");
		private static readonly int StartTime_ID = Shader.PropertyToID("_StartTime");
		private static readonly int ColorMapTex_ID = Shader.PropertyToID("_ColorMapTex");

		#region Allocation/deallocation

		public static FlipBookPage
			Allocate(int index, int w, int h)
		{
			var rt = new RenderTexture(w, h, 0);
			rt.name = "FlipBook" + index;
			return new FlipBookPage(rt);
		}

		public static void Deallocate(FlipBookPage page)
			=> Object.Destroy(page._rt);

		#endregion

		#region Public method

		public FlipBookPage StartFlipping(CommandBuffer cmd,
			float speed, float time, RenderTargetIdentifier rti)
		{
			_startTime = time;
			_speed = speed;
			cmd.Blit(rti, _rt);
			return this;
		}

		public FlipBookPage LoopFlipping(MaterialPropertyBlock mpb)
		{
			mpb.SetFloat(Speed_ID, _speed);
			mpb.SetFloat(StartTime_ID, _startTime);
			mpb.SetTexture(ColorMapTex_ID, _rt);
			return this;
		}

		#endregion

		#region Private members

		private RenderTexture _rt { get; }

		private float _startTime = 0;
		private float _speed = 0;


		private FlipBookPage(RenderTexture rt)
			=> (_rt) = (rt);

		#endregion
	}
}