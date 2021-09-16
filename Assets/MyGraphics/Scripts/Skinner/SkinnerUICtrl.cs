using System;
using UnityEngine;
using UnityEngine.UI;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerUICtrl : MonoBehaviour
	{
		public Toggle useMRTToggle;
		public Toggle debugToggle;
		public Toggle glitchToggle;
		public Toggle particleAsteroidsToggle;
		public Toggle particleShardsToggle;
		public Toggle trailToggle;

		public GameObject debugObj;
		public GameObject glitchObj;
		public GameObject particleAsteroidsObj;
		public GameObject particleShardsObj;
		public GameObject trailObj;


		public void Awake()
		{
			AddEvent(debugToggle, debugObj);
			AddEvent(glitchToggle, glitchObj);
			AddEvent(particleAsteroidsToggle, particleAsteroidsObj);
			AddEvent(particleShardsToggle, particleShardsObj);
			AddEvent(trailToggle, trailObj);
		}

		private void AddEvent(Toggle tog, GameObject obj)
		{
			tog.isOn = obj.activeInHierarchy;
			tog.transform.GetChild(1).GetComponent<Text>().text = obj.name;
			tog.onValueChanged.AddListener(obj.SetActive);
			var set = obj.GetComponent<ISkinnerSetting>();
			set.UseMRT = useMRTToggle.isOn;
			useMRTToggle.onValueChanged.AddListener(x => set.UseMRT = x);
		}
	}
}