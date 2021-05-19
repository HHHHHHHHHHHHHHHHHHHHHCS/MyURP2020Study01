using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public class MyCustomPostProcessPass : ScriptableRenderPass
	{
		private const string k_tag = "MyCustomPostProcess";

		
		private MyCustomPostProcessFeature.MyCustomPostProcessShaders shader;
		
		public void Init(MyCustomPostProcessFeature.MyCustomPostProcessShaders _shaders)
		{
			shader = _shaders;
			profilingSampler = new ProfilingSampler(k_tag);
		}
		
		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}


	}
}
