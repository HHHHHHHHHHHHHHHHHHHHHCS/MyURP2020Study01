using Graphics.Scripts.UnityChanSSU;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace Graphics.Editor.UnityChanSSU
{
	[VolumeComponentEditor(typeof(MyVignettePostProcess))]
	public class MyVignettePostProcessEditor : VolumeComponentEditor
	{
		public override void OnEnable()
		{
			var o = new PropertyFetcher<MyVignettePostProcess>(serializedObject);

		}

		public override void OnInspectorGUI()
		{
			// if (UniversalRenderPipeline.asset?.postProcessingFeatureSet == PostProcessingFeatureSet.PostProcessingV2)
			// {
			// 	EditorGUILayout.HelpBox(UniversalRenderPipelineAssetEditor.Styles.postProcessingGlobalWarning,
			// 		MessageType.Warning);
			// 	return;
			// }

			EditorGUILayout.LabelField("MyVignette", EditorStyles.miniLabel);
            
		}
	}
}
