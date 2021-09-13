using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerDebugAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Debug Attr";

		private List<SkinnerDebug> debugs;
		private Material mat;

		public SkinnerDebugAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void OnSetup(List<SkinnerDebug> _debugs, Material _mat)
		{
			debugs = _debugs;
			mat = _mat;
		}

		public void OnDestroy()
		{
			debugs = null;
			mat = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				foreach (var debug in debugs)
				{
					var source = debug.Source;

					if (source.Width == 0 || source.Data.isFirst)
					{
						continue;
					}

					var vertData = source.Data;

					cmd.SetGlobalTexture(DebugPositionTex_ID, vertData.CurrPosTex);
					cmd.SetGlobalTexture(DebugNormalTex_ID, vertData.NormalTex);
					cmd.SetGlobalTexture(DebugTangentTex_ID, vertData.TangentTex);
					cmd.SetGlobalTexture(DebugPrevPositionTex_ID, vertData.PrevPosTex);

					cmd.DrawProcedural(Matrix4x4.identity, mat, 0, MeshTopology.Lines, 6 * debug.Source.Width, 1);

					// context.ExecuteCommandBuffer(cmd);
					// cmd.Clear();
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}