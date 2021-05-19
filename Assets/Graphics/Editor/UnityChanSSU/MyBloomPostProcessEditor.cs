using Graphics.Scripts.UnityChanSSU;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace Graphics.Editor.UnityChanSSU
{
	[VolumeComponentEditor(typeof(MyBloomPostProcess))]
	public class MyBloomPostProcessEditor : VolumeComponentEditor
	{
		public override void OnEnable()
		{
			var o = new PropertyFetcher<MyBloomPostProcess>(serializedObject);

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
            
		}
	}
}
