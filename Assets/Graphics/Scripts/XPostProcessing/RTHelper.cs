using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace Graphics.Scripts.XPostProcessing
{
	public class RTHelper
	{
		private static readonly RenderTargetIdentifier cameraColorTex_RTI =
			new RenderTargetIdentifier("_CameraColorTexture");

		private static readonly int SrcTex_ID = Shader.PropertyToID("_SrcTex");

		private static readonly int TempRT0_ID = Shader.PropertyToID("_TempRT0");

		private static readonly int TempRT1_ID = Shader.PropertyToID("_TempRT1");

		private static readonly RenderTargetIdentifier TempRT0_RTI = new RenderTargetIdentifier(TempRT0_ID);

		private static readonly RenderTargetIdentifier TempRT1_RTI = new RenderTargetIdentifier(TempRT1_ID);

		private static int src, dest;
		private static int width, height;
		private static RenderTextureDescriptor descriptor;

		public static void SetupTempRT(int _width, int _height, RenderTextureDescriptor _desc)
		{
			src = -1;
			dest = -1;
			width = _width;
			height = _height;
			descriptor = _desc;
		}

		public static void ReleaseTempRT(CommandBuffer cmd)
		{
			if (src != -1)
			{
				cmd.ReleaseTemporaryRT(src);
				src = -1;
			}

			if (dest != -1)
			{
				cmd.ReleaseTemporaryRT(dest);
				dest = -1;
			}
		}

		public static RenderTargetIdentifier GetSrc(CommandBuffer cmd)
		{
			if (src == -1)
			{
				return cameraColorTex_RTI;
			}

			return src == TempRT0_ID ? TempRT0_RTI : TempRT1_RTI;
		}

		public static RenderTargetIdentifier GetDest(CommandBuffer cmd)
		{
			// return BuiltinRenderTextureType.CameraTarget;
			if (dest == -1)
			{
				var desc = GetRenderDescriptor(width, height, descriptor.graphicsFormat);

				if (src == TempRT1_ID || src == -1)
				{
					cmd.GetTemporaryRT(TempRT0_ID, desc);
					dest = TempRT0_ID;
				}
				else if (src == TempRT0_ID)
				{
					cmd.GetTemporaryRT(TempRT1_ID, desc);
					dest = TempRT1_ID;
				}
			}

			return dest == TempRT0_ID ? TempRT0_RTI : TempRT1_RTI;
		}


		private static void SwapRT()
		{
			CoreUtils.Swap(ref src, ref dest);
		}

		private static bool SrcIsFinal(CommandBuffer cmd) => GetSrc(cmd) == cameraColorTex_RTI;

		private static RenderTextureDescriptor GetRenderDescriptor(int _width, int _height, GraphicsFormat _format)
		{
			var desc = descriptor;

			desc.width = _width;
			desc.height = _height;
			desc.depthBufferBits = 0;
			desc.msaaSamples = 1;
			desc.graphicsFormat = _format;

			return desc;
		}

		private static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier dest,
			Material mat, int pass = 0)
		{
			cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
			CoreUtils.DrawFullScreen(cmd, mat, null, pass);
		}

		private static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier src, RenderTargetIdentifier dest,
			Material mat, int pass)
		{
			cmd.SetGlobalTexture(SrcTex_ID, src);
			DrawFullScreen(cmd, dest, mat, pass);
		}
	}
}