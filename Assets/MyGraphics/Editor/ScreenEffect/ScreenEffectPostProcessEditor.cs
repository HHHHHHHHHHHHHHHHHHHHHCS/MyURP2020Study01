/*
using Graphics.Scripts.ScreenEffect;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace Graphics.Editor.ScreenEffect
{
	[VolumeComponentEditor(typeof(ScreenEffectPostProcess))]
	public class ScreenEffectPostProcessEditor : VolumeComponentEditor
	{
		private SerializedDataParameter m_enableEffect;

		public override void OnEnable()
		{
			var o = new PropertyFetcher<ScreenEffectPostProcess>(serializedObject);

			m_enableEffect = Unpack(o.Find(x => x.enableEffect));
		}

		public override void OnInspectorGUI()
		{
			// if (UniversalRenderPipeline.asset?.postProcessingFeatureSet == PostProcessingFeatureSet.PostProcessingV2)
			// {
			// 	EditorGUILayout.HelpBox(UniversalRenderPipelineAssetEditor.Styles.postProcessingGlobalWarning,
			// 		MessageType.Warning);
			// 	return;
			// }

			EditorGUILayout.LabelField("ScreenEffect", EditorStyles.miniLabel);
            
			PropertyField(m_enableEffect);
		}
	}
}
*/