using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public static class SkinnerShaderConstants
	{
		public static int SrcTex_ID = Shader.PropertyToID("_SrcTex");
		public static int SourcePositionTex0_ID = Shader.PropertyToID("_SourcePositionTex0");
		public static int SourcePositionTex1_ID = Shader.PropertyToID("_SourcePositionTex1");
		public static int PositionTex_ID = Shader.PropertyToID("_PositionTex");
		public static int VelocityTex_ID = Shader.PropertyToID("_VelocityTex");
		public static int RotationTex_ID = Shader.PropertyToID("_RotationTex");
		public static int ObjPositionTex_ID = Shader.PropertyToID("_ObjPositionTex");
		public static int ObjVelocityTex_ID = Shader.PropertyToID("_ObjVelocityTex");
		public static int ObjRotationTex_ID = Shader.PropertyToID("_ObjRotationTex");
		public static int ObjPrevPositionTex_ID = Shader.PropertyToID("_ObjPrevPositionTex");
		public static int ObjPrevRotationTex_ID = Shader.PropertyToID("_ObjPrevRotationTex");
		
		public static int RandomSeed_ID = Shader.PropertyToID("_RandomSeed");
		public static int Damper_ID = Shader.PropertyToID("_Damper");
		public static int Gravity_ID = Shader.PropertyToID("_Gravity");
		public static int Life_ID = Shader.PropertyToID("_Life");
		public static int Spin_ID = Shader.PropertyToID("_Spin");
		public static int NoiseParams_ID = Shader.PropertyToID("_NoiseParams");
		public static int NoiseOffset_ID = Shader.PropertyToID("_NoiseOffset");
		
		public static int Scale_ID = Shader.PropertyToID("_Scale");
	}

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