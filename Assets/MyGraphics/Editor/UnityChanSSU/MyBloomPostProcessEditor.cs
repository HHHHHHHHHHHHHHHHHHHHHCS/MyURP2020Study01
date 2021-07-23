using MyGraphics.Scripts.UnityChanSSU;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace MyGraphics.Editor.UnityChanSSU
{
	[VolumeComponentEditor(typeof(MyBloomPostProcess))]
	public class MyBloomPostProcessEditor : VolumeComponentEditor
	{
		private SerializedDataParameter m_Intensity;
		private SerializedDataParameter m_Threshold;
		private SerializedDataParameter m_SoftKnee;
		private SerializedDataParameter m_Clamp;
		private SerializedDataParameter m_Diffusion;
		private SerializedDataParameter m_AnamorphicRatio;
		private SerializedDataParameter m_Color;
		private SerializedDataParameter m_FastMode;
		
		private SerializedDataParameter m_DirtTexture;
		private SerializedDataParameter m_DirtIntensity;
		
		public override void OnEnable()
		{
			var o = new PropertyFetcher<MyBloomPostProcess>(serializedObject);
			m_Intensity = Unpack(o.Find(x => x.intensity));
			m_Threshold = Unpack(o.Find(x => x.threshold));
			m_SoftKnee = Unpack(o.Find(x => x.softKnee));
			m_Clamp = Unpack(o.Find(x => x.clamp));
			m_Diffusion = Unpack(o.Find(x => x.diffusion));
			m_AnamorphicRatio = Unpack(o.Find(x => x.anamorphicRatio));
			m_Color = Unpack(o.Find(x => x.color));
			m_FastMode = Unpack(o.Find(x => x.fastMode));
			
			m_DirtTexture = Unpack(o.Find(x => x.dirtTexture));
			m_DirtIntensity = Unpack(o.Find(x => x.dirtIntensity));
		}

		public override void OnInspectorGUI()
		{
			// if (UniversalRenderPipeline.asset?.postProcessingFeatureSet == PostProcessingFeatureSet.PostProcessingV2)
			// {
			// 	EditorGUILayout.HelpBox(UniversalRenderPipelineAssetEditor.Styles.postProcessingGlobalWarning,
			// 		MessageType.Warning);
			// 	return;
			// }

			EditorGUILayout.LabelField("MyBloom", EditorStyles.miniLabel);
            
			PropertyField(m_Intensity);
			PropertyField(m_Threshold);
			PropertyField(m_SoftKnee);
			PropertyField(m_Clamp);
			PropertyField(m_Diffusion);
			PropertyField(m_AnamorphicRatio);
			PropertyField(m_Color);
			PropertyField(m_FastMode);

			EditorGUILayout.Space();
			EditorGUILayout.LabelField("Dirtiness", EditorStyles.miniLabel);

			PropertyField(m_DirtTexture);
			PropertyField(m_DirtIntensity);
			
			if (UnityEngine.XR.XRSettings.enabled)
			{
				if ((m_DirtIntensity.overrideState.boolValue && m_DirtIntensity.value.floatValue > 0f)
				    || (m_DirtTexture.overrideState.boolValue && m_DirtTexture.value.objectReferenceValue != null))
					EditorGUILayout.HelpBox("Using a dirt texture in VR is not recommended.", MessageType.Warning);
			}
		}
	}
}
