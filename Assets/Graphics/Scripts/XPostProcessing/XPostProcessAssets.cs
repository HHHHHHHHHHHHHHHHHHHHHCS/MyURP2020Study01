using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.XPostProcessing
{
	[System.Serializable]
	public class XPostProcessAssets
	{
		[SerializeField] private Shader blitShader;
		
		[Header("Glitch")]
		[SerializeField] private Shader imageBlockShader;
		
		[Header("Vignette")]
		[SerializeField] private Shader auroraVignetteShader;
		[SerializeField] private Shader rapidVignetteShader;

		[Header("ImageProcessing")]
		[SerializeField] private Shader sharpenV1Shader;
		[SerializeField] private Shader sharpenV2Shader;
		[SerializeField] private Shader sharpenV3Shader;

		
		private Material blitMaterial;
		private Material imageBlockMaterial;
		private Material auroratVignetteMaterial;
		private Material rapidVignetteMaterial;
		private Material sharpenV1Material;
		private Material sharpenV2Material;
		private Material sharpenV3Material;


		public Material BlitMat => ToolsHelper.GetCreateMaterial(ref blitShader, ref blitMaterial);
		public Material ImageBlockMat => ToolsHelper.GetCreateMaterial(ref imageBlockShader, ref imageBlockMaterial);
		public Material AuroraVignetteMat => ToolsHelper.GetCreateMaterial(ref auroraVignetteShader, ref auroratVignetteMaterial);
		public Material rapidVignetteMat => ToolsHelper.GetCreateMaterial(ref rapidVignetteShader, ref rapidVignetteMaterial);

		public Material SharpenV1Mat => ToolsHelper.GetCreateMaterial(ref sharpenV1Shader, ref sharpenV1Material);
		public Material SharpenV2Mat => ToolsHelper.GetCreateMaterial(ref sharpenV2Shader, ref sharpenV2Material);
		public Material SharpenV3Mat => ToolsHelper.GetCreateMaterial(ref sharpenV3Shader, ref sharpenV3Material);


		public void DestroyMaterials()
		{
			ToolsHelper.DestroyMaterial(ref blitMaterial);
			ToolsHelper.DestroyMaterial(ref imageBlockMaterial);
			ToolsHelper.DestroyMaterial(ref auroratVignetteMaterial);
			ToolsHelper.DestroyMaterial(ref rapidVignetteMaterial);
			ToolsHelper.DestroyMaterial(ref sharpenV1Material);
			ToolsHelper.DestroyMaterial(ref sharpenV2Material);
			ToolsHelper.DestroyMaterial(ref sharpenV3Material);

#if UNITY_EDITOR
			Debug.Log("XPostProcessAssets.DestroyMaterials");
#endif
		}
	}
}