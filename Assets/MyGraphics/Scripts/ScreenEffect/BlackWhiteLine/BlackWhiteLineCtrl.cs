using System;
using UnityEngine;

namespace MyGraphics.Scripts.ScreenEffect.BlackWhiteLine
{
	public class BlackWhiteLineCtrl : MonoBehaviour
	{
		public Material effectMat;

		private BlackWhiteLinePass blackWhiteLinePass;

		private void Start()
		{
			blackWhiteLinePass = new BlackWhiteLinePass(effectMat);
			ScreenEffectFeature.renderPass = blackWhiteLinePass;
		}
	}
}