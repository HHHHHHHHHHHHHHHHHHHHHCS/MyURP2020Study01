using System;
using UnityEngine;

namespace Graphics.Scripts.ScreenEffect.BlackWhiteLine
{
	public class BlackWhiteLineCtrl : MonoBehaviour
	{
		private const string k_tag = "BlackWhite";
		
		public Material effectMat;

		private BlackWhiteLinePass blackWhiteLinePass;

		private void Start()
		{
			blackWhiteLinePass = new BlackWhiteLinePass(effectMat);
			ScreenEffectFeature.renderPass = blackWhiteLinePass;
		}
	}
}