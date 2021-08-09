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
		[SerializeField] private Shader imageBlockV2Shader;
		[SerializeField] private Shader imageBlockV4Shader;
		[SerializeField] private Shader rgbSplitV5Shader;
		[SerializeField] private Shader waveJitterShader;
		[SerializeField] private Shader lineBlockShader;


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
		private Material imageBlockV2Material;
		private Material imageBlockV4Material;
		private Material rgbSplitV5Material;
		private Material waveJitterMaterial;
		private Material lineBlockMaterial;

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

		public Material ImageBlockV2Mat =>
			ToolsHelper.GetCreateMaterial(ref imageBlockV2Shader, ref imageBlockV2Material);

		public Material ImageBlockV4Mat =>
			ToolsHelper.GetCreateMaterial(ref imageBlockV4Shader, ref imageBlockV4Material);

		public Material RGBSplitV5Mat => ToolsHelper.GetCreateMaterial(ref rgbSplitV5Shader, ref rgbSplitV5Material);
		public Material WaveJitterMat => ToolsHelper.GetCreateMaterial(ref waveJitterShader, ref waveJitterMaterial);
		public Material LineBlockMat => ToolsHelper.GetCreateMaterial(ref lineBlockShader, ref lineBlockMaterial);

		//Vignette-----------
		public Material AuroraVignetteMat =>
			ToolsHelper.GetCreateMaterial(ref auroraVignetteShader, ref auroratVignetteMaterial);

		public Material RapidVignetteMat =>
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
			ToolsHelper.DestroyMaterial(ref imageBlockV2Material);
			ToolsHelper.DestroyMaterial(ref imageBlockV4Material);
			ToolsHelper.DestroyMaterial(ref rgbSplitV5Material);
			ToolsHelper.DestroyMaterial(ref waveJitterMaterial);
			ToolsHelper.DestroyMaterial(ref lineBlockMaterial);
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