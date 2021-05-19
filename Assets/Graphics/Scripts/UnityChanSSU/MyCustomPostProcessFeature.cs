using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public class MyCustomPostProcessFeature : ScriptableRendererFeature
	{
		[System.Serializable]
		public class MyCustomPostProcessShaders
		{
			[SerializeField] private Shader bloomShader;
			[SerializeField] private Shader uberShader;
			[SerializeField] private Shader stylizedTonemapShader;
			[SerializeField] private Shader finalShader;

			public Shader BloomShader => bloomShader;
			public Shader UberShader => uberShader;
			public Shader StylizedTonemapShader => stylizedTonemapShader;
			public Shader FinalShader => finalShader;
		}

		public MyCustomPostProcessShaders shaders;

		private MyCustomPostProcessPass myCustomPostProcessPass;

		public override void Create()
		{
			if (shaders == null)
			{
				return;
			}
			
			myCustomPostProcessPass = new MyCustomPostProcessPass()
			{
				renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing,
			};
			myCustomPostProcessPass.Init(shaders);
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (shaders == null || myCustomPostProcessPass == null)
			{
				return;
			}

			//为什么不添加限制 renderingData.postProcessingEnabled
			//因为enable之后  URP  就算什么也没有加  也会有一次LUT
			
			renderer.EnqueuePass(myCustomPostProcessPass);
		}
	}
}