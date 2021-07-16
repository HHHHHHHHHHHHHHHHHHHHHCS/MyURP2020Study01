using Graphics.Scripts.XPostProcessing.Vignette;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Graphics.Editor.XPostProcessing.Vignette
{
	[VolumeComponentEditor(typeof(RapidVignettePostProcess))]
	public class RapidVignettePostProcessEditor : VolumeComponentEditor
	{
		private SerializedDataParameter m_enableEffect;
		private SerializedDataParameter m_priorityQueue;
		private SerializedDataParameter m_vignetteArea;
		private SerializedDataParameter m_vignetteIntensity;
		private SerializedDataParameter m_vignetteCenter;
		private SerializedDataParameter m_vignetteColor;

		public override void OnEnable()
		{
			var o = new PropertyFetcher<RapidVignettePostProcess>(serializedObject);
			
			m_enableEffect = Unpack(o.Find(x => x.enableEffect));
			m_priorityQueue = Unpack(o.Find(x => x.priorityQueue));
			m_vignetteArea = Unpack(o.Find(x => x.vignetteArea));
			m_vignetteIntensity = Unpack(o.Find(x => x.vignetteIntensity));
			m_vignetteCenter = Unpack(o.Find(x => x.vignetteCenter));
			m_vignetteColor = Unpack(o.Find(x => x.vignetteColor));
		}

		public override void OnInspectorGUI()
		{
			PropertyField(m_enableEffect);
			PropertyField(m_priorityQueue);
			PropertyField(m_vignetteArea);
			PropertyField(m_vignetteIntensity);
			PropertyField(m_vignetteCenter);
			if (m_vignetteArea.value.intValue == (int) RapidVignettePostProcess.VignetteType.ColorMode)
			{
				PropertyField(m_vignetteColor);
			}
		}
	}
}