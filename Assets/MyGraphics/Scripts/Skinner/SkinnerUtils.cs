using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public static class SkinnerUtils
	{
		public static void CreateRT(ref RenderTexture rt, int w, int h, string name = null)
		{
			CleanRT(ref rt);
			rt = new RenderTexture(w, h, 0, RenderTextureFormat.ARGBFloat)
			{
				filterMode = FilterMode.Point,
				wrapMode = TextureWrapMode.Clamp,
				name = name ?? Guid.NewGuid().ToString(),
			};
		}


		public static void CleanRT(ref RenderTexture rt)
		{
			CoreUtils.Destroy(rt);
			rt = null;
		}

		private static void Blit(CommandBuffer cmd, RenderTargetIdentifier src, RenderTargetIdentifier dest,
			Material mat, int pass, int mipmap = 0)
		{
			if (mipmap != 0)
			{
				dest = new RenderTargetIdentifier(dest, mipmap);
			}

			cmd.SetRenderTarget(dest, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);

			cmd.SetGlobalTexture(SkinnerShaderConstants.SrcTex_ID, src);

			CoreUtils.DrawFullScreen(cmd, mat, null, pass);
		}


		public static void DrawFullScreen(CommandBuffer cmd, RenderTargetIdentifier dst, Material mat, int pass = 0)
		{
			cmd.SetRenderTarget(dst, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
			CoreUtils.DrawFullScreen(cmd, mat, null, pass);
		}
	}
}