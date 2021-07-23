using System;
using System.Collections.Generic;
using UnityEngine;

namespace MyGraphics.Scripts.UnityChanSSU
{
	public class Animation_ShirtLED : MonoBehaviour
	{
		private static readonly int MainTex_ID = Shader.PropertyToID("_MainTex");
		private static readonly int ShadowColor1stTex_ID = Shader.PropertyToID("_ShadowColor1stTex");
		private static readonly int ShadowColor2ndTex_ID = Shader.PropertyToID("_ShadowColor2ndTex");
		private static readonly int Color_ID = Shader.PropertyToID("_Color");
		private static readonly int ShadowColor1st_ID = Shader.PropertyToID("_ShadowColor1st");
		private static readonly int ShadowColor2nd_ID = Shader.PropertyToID("_ShadowColor2nd");
		
		public float textureSpeed = 1.0f;
		public List<Texture2D> textures = new List<Texture2D>();

		public float colorSpeed = 1.0f;
		public Gradient colorGradient = new Gradient();

		private MaterialPropertyBlock propertyBlock;
		private SkinnedMeshRenderer meshRenderer;


		private void Start()
		{
			propertyBlock = new MaterialPropertyBlock();
			meshRenderer = GetComponent<SkinnedMeshRenderer>();
		}

		private void Update()
		{
			if (meshRenderer == null)
			{
				return;
			}
			
			float textureTime = Mathf.Sin(Time.time * textureSpeed) * 0.5f + 0.5f;
			float textureStep = 1.0f / textures.Count;

			Texture2D texture = null;
			for (int i = 0; i < textures.Count; i++)
			{
				if (textureTime < textureStep * (i + 1))
				{
					texture = textures[i];
					break;
				}
			}

			texture = texture != null ? texture : Texture2D.blackTexture;
			propertyBlock.SetTexture(MainTex_ID, texture);
			propertyBlock.SetTexture(ShadowColor1stTex_ID, texture);
			propertyBlock.SetTexture(ShadowColor2ndTex_ID, texture);

			float colorTime = Mathf.Sin(Time.time * colorSpeed) * 0.5f + 0.5f;

			Color color = colorGradient.Evaluate(colorTime);
			propertyBlock.SetColor(Color_ID, color);
			propertyBlock.SetColor(ShadowColor1st_ID, color);
			propertyBlock.SetColor(ShadowColor2nd_ID, color);

			meshRenderer.SetPropertyBlock(propertyBlock);
		}
	}
}