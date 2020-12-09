using UnityEngine;

namespace Graphics.Scripts.AreaLight
{
	[System.Serializable]
	public class MyAreaLightLUT : ScriptableObject
	{
		public enum LUTType
		{
			TransformInv_DisneyDiffuse,
			TransformInv_GGX,
			AmpDiffAmpSpecFresnel
		}
		
		public Texture2D transformInvTexture_Specular;
		public Texture2D transformInvTexture_Diffuse;
		public Texture2D ampDiffAmpSpecFresnel;
	}
}