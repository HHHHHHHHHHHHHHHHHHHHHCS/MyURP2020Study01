using UnityEngine;

namespace MyGraphics.Scripts.XPostProcessing.Common
{
	[System.Serializable]
	public class XPostProcessAssets
	{
		[SerializeField] private Shader blitShader;

		[Header("EdgeDetection")] [SerializeField]
		private Shader scharrShader;

		[Header("Glitch")] [SerializeField] private Shader imageBlockShader;

		[Header("Vignette")] [SerializeField] private Shader auroraVignetteShader;
		[SerializeField] private Shader rapidVignetteShader;

		[Header("ImageProcessing")] [SerializeField]
		private Shader sharpenV1Shader;

		[SerializeField] private Shader sharpenV2Shader;
		[SerializeField] private Shader sharpenV3Shader;


		private Material blitMaterial;

		//EdgeDetection-----------
		private Material scharrMaterial;

		//Glitch-----------
		private Material imageBlockMaterial;

		//Vignette-----------
		private Material auroratVignetteMaterial;

		private Material rapidVignetteMaterial;

		//ImageProcessing-----------
		private Material sharpenV1Material;
		private Material sharpenV2Material;
		private Material sharpenV3Material;


		public Material BlitMat => ToolsHelper.GetCreateMaterial(ref blitShader, ref blitMaterial);

		//EdgeDetection-----------
		public Material ScharrMat => ToolsHelper.GetCreateMaterial(ref scharrShader, ref scharrMaterial);

		//Glitch-----------
		public Material ImageBlockMat => ToolsHelper.GetCreateMaterial(ref imageBlockShader, ref imageBlockMaterial);

		//Vignette-----------
		public Material AuroraVignetteMat =>
			ToolsHelper.GetCreateMaterial(ref auroraVignetteShader, ref auroratVignetteMaterial);

		public Material rapidVignetteMat =>
			ToolsHelper.GetCreateMaterial(ref rapidVignetteShader, ref rapidVignetteMaterial);

		//ImageProcessing-----------
		public Material SharpenV1Mat => ToolsHelper.GetCreateMaterial(ref sharpenV1Shader, ref sharpenV1Material);
		public Material SharpenV2Mat => ToolsHelper.GetCreateMaterial(ref sharpenV2Shader, ref sharpenV2Material);
		public Material SharpenV3Mat => ToolsHelper.GetCreateMaterial(ref sharpenV3Shader, ref sharpenV3Material);


		public void DestroyMaterials()
		{
			ToolsHelper.DestroyMaterial(ref blitMaterial);
			ToolsHelper.DestroyMaterial(ref scharrMaterial);
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