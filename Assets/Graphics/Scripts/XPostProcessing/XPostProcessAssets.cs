using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.XPostProcessing
{
	[System.Serializable]
	public class XPostProcessAssets
	{
		[SerializeField] private Shader blitShader;
		[SerializeField] private Shader sharpenV1Shader;

		private Material blitMaterial;
		private Material sharpenV1Material;

		public Material BlitMat => ToolsHelper.GetCreateMaterial(ref blitShader, ref blitMaterial);
		public Material SharpenV1Mat => ToolsHelper.GetCreateMaterial(ref sharpenV1Shader, ref sharpenV1Material);


		public void DestroyMaterials()
		{
			ToolsHelper.DestroyMaterial(ref blitMaterial);
			ToolsHelper.DestroyMaterial(ref sharpenV1Material);

#if UNITY_EDITOR
			Debug.Log("XPostProcessAssets.DestroyMaterials");
#endif
		}
	}
}