using System;
using UnityEngine;

namespace Graphics.Scripts.ScreenEffect.BlackWhiteLine
{
	public class BlackWhiteLineCtrl : MonoBehaviour
	{
		private const string k_tag = "BlackWhite";
		
		public Material outlineMat;
		public Material explodeMat;

		private BlackWhiteLinePass blackWhiteLinePass;

		private void Start()
		{
			blackWhiteLinePass = new BlackWhiteLinePass(outlineMat, explodeMat);
			ScreenEffectFeature.renderPass = blackWhiteLinePass;
		}
	}
}