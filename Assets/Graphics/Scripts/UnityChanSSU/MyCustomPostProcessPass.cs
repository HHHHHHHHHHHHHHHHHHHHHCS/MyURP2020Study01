using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public class MyCustomPostProcessPass : ScriptableRenderPass
	{
		private const string k_tag = "MyCustomPostProcess";

		private const string k_bloomTag = "MyBloom";
		private const string k_uberTag = "MyUber";
		private const string k_stylizedTonemapTag = "StylizedTonemap";
		private const string k_finalTag = "MyFianl";

		private MyCustomPostProcessShaders shaders;
		
		private ProfilingSampler bloomProfilingSampler;
		private ProfilingSampler uberProfilingSampler;
		private ProfilingSampler stylizedTonemapProfilingSampler;
		private ProfilingSampler finalProfilingSampler;


		public void Init(MyCustomPostProcessShaders _shaders)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			shaders = _shaders;
			
			bloomProfilingSampler = new ProfilingSampler(k_bloomTag);
			uberProfilingSampler = new ProfilingSampler(k_uberTag);
			stylizedTonemapProfilingSampler = new ProfilingSampler(k_stylizedTonemapTag);
			finalProfilingSampler = new ProfilingSampler(k_finalTag);

		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var stack = VolumeManager.instance.stack;
				var bloomSettings = stack.GetComponent<MyBloomPostProcess>();
				if (bloomSettings != null && bloomSettings.IsActive())
				{
					using (new ProfilingScope(cmd, bloomProfilingSampler))
					{
						DoBloom(cmd);
					}
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		private void DoBloom(CommandBuffer cmd)
		{
		}
	}
}