using Graphics.Scripts.AtmosphericScattering;
using UnityEditor;
using UnityEditor.Rendering;

namespace Graphics.Editor.AtmosphericScattering
{
    [VolumeComponentEditor(typeof(LightShaftPostProcess))]

    public class LightShaftPostProcessEditor : VolumeComponentEditor
    {
        private SerializedDataParameter m_enableEffect;

        public override void OnEnable()
        {
            var o = new PropertyFetcher<LightShaftPostProcess>(serializedObject);

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

            EditorGUILayout.LabelField("Scattering-LightShaft", EditorStyles.miniLabel);
            
            PropertyField(m_enableEffect);
        }
    }
}
