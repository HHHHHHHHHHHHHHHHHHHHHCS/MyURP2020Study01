using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// https://zhuanlan.zhihu.com/p/232450616
namespace Graphics.Scripts.HairShadow
{
	public class HairShadowFeature : ScriptableRendererFeature
	{
		[System.Serializable]
		public class Setting
		{
			public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingOpaques;
			//face是renderlayer2=>2
			public uint faceRenderLayer;
			//hair是renderlayer3=>4
			public uint hairRenderLayer;
			[Range(1000, 5000)] public int queueMin = 2000;

			[Range(1000, 5000)] public int queueMax = 3000;
			public Shader depthShader;
		}

		public Setting setting = new Setting();

		private HairShadowPass hairShadowPass;
		private Material depthMat;

		public override void Create()
		{
			if (depthMat != null && depthMat.shader != setting.depthShader)
			{
				DestroyImmediate(depthMat);
				depthMat = null;
			}

			if (setting.depthShader == null)
			{
				return;
			}
			
			depthMat = CoreUtils.CreateEngineMaterial(setting.depthShader);

			hairShadowPass = new HairShadowPass(setting,depthMat)
			{
				renderPassEvent = setting.passEvent
			};
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (depthMat == null)
			{
				return;
			}
			renderer.EnqueuePass(hairShadowPass);
		}
	}
}