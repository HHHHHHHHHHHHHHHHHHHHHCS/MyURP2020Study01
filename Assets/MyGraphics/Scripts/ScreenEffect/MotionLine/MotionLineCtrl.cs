using System;
using UnityEngine;

namespace MyGraphics.Scripts.ScreenEffect.MotionLine
{
	public class MotionLineCtrl : MonoBehaviour
	{
		public Material effectMat;

		private MotionLinePass motionLinePass;

		private void Start()
		{
			motionLinePass = new MotionLinePass(effectMat);
			ScreenEffectFeature.renderPass = motionLinePass;
		}

		private void OnDestroy()
		{
			motionLinePass?.OnDestroy();
		}
	}
}