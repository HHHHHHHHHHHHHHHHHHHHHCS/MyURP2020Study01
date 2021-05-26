using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace Graphics.Scripts.UnityChanSSU
{
	[System.Serializable]
	public class MyCustomPostProcessShaders
	{
		[SerializeField] private Shader bloomShader;
		[SerializeField] private Shader uberShader;
		[SerializeField] private Shader stylizedTonemapShader;
		[SerializeField] private Shader msaaShader;
		[SerializeField] private Shader finalShader;

		// public Shader BloomShader => bloomShader;
		// public Shader UberShader => uberShader;
		// public Shader StylizedTonemapShader => stylizedTonemapShader;
		// public Shader FinalShader => finalShader;

		private Material _bloomMaterial;
		private Material _uberMaterial;
		private Material _stylizedTonemapMaterial;
		private Material _msaaMaterial;
		private Material _finalMaterial;

		public Material BloomMaterial
		{
			get
			{
				GetMaterial(ref _bloomMaterial, ref bloomShader);

				return _bloomMaterial;
			}
		}

		public Material UberMaterial
		{
			get
			{
				GetMaterial(ref _uberMaterial, ref uberShader);

				return _uberMaterial;
			}
		}

		public Material StylizedTonemapMaterial
		{
			get
			{
				GetMaterial(ref _stylizedTonemapMaterial, ref stylizedTonemapShader);

				return _stylizedTonemapMaterial;
			}
		}
		
		public Material MSAAMaterial
		{
			get
			{
				GetMaterial(ref _msaaMaterial, ref msaaShader);

				return _msaaMaterial;
			}
		}


		public Material FinalMaterial
		{
			get
			{
				GetMaterial(ref _finalMaterial, ref finalShader);

				return _finalMaterial;
			}
		}


		~MyCustomPostProcessShaders()
		{
			DestroyMaterials();
		}
		
		private void GetMaterial(ref Material mat, ref Shader shader)
		{
			if (mat != null && mat.shader != shader)
			{
				Object.DestroyImmediate(mat);
				mat = null;
			}

			if (mat == null && shader != null)
			{
				mat = CoreUtils.CreateEngineMaterial(shader);
			}
		}

		private void SafeDestroyMaterial(ref Material mat)
		{
			if (mat != null)
			{
				Object.DestroyImmediate(mat);
				mat = null;
			}
		}

		public void DestroyMaterials()
		{
			SafeDestroyMaterial(ref _bloomMaterial);
			SafeDestroyMaterial(ref _uberMaterial);
			SafeDestroyMaterial(ref _stylizedTonemapMaterial);
			SafeDestroyMaterial(ref _msaaMaterial);
			SafeDestroyMaterial(ref _finalMaterial);
#if UNITY_EDITOR
			Debug.Log("MyCustomPostProcessShaders.DestroyMaterials");
#endif
		}
	}

	public class MyCustomPostProcessFeature : ScriptableRendererFeature
	{
		public bool enableEffect;

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

		protected override void Dispose(bool disposing)
		{
			shaders?.DestroyMaterials();
			myCustomPostProcessPass?.OnDestroy();
		}


		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (enableEffect == false || shaders == null || myCustomPostProcessPass == null)
			{
				return;
			}

			//为什么不添加限制 renderingData.postProcessingEnabled
			//因为enable之后  URP  就算什么也没有加  也会有一次LUT
			renderer.EnqueuePass(myCustomPostProcessPass);
		}
	}
}