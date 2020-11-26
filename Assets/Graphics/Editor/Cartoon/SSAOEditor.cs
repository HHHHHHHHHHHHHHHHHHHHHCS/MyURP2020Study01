using Graphics.Scripts;
using Graphics.Scripts.Cartoon;
using UnityEditor;
using UnityEngine;

namespace Graphics.Editor.Cartoon
{
	[CustomEditor(typeof(SSAOFeature))]
	public class SSAOEditor : UnityEditor.Editor
	{
		#region Serialized Properties

		private SerializedProperty m_Downsample;
		private SerializedProperty m_Source;
		private SerializedProperty m_NormalQuality;
		private SerializedProperty m_Intensity;
		private SerializedProperty m_DirectLightingStrength;
		private SerializedProperty m_Radius;
		private SerializedProperty m_SampleCount;

		#endregion

		private bool m_IsInitialized = false;

		// Structs
		private struct Styles
		{
			public static GUIContent Downsample = EditorGUIUtility.TrTextContent("Downsample",
				"With this option enabled, Unity downsamples the SSAO effect texture to improve performance. Each dimension of the texture is reduced by a factor of 2.");

			public static GUIContent Source = EditorGUIUtility.TrTextContent("Source",
				"This option determines whether the ambient occlusion reconstructs the normal from depth or is given it from a DepthNormal/Deferred Gbuffer texture.");

			public static GUIContent NormalQuality = new GUIContent("Normal Quality",
				"The options in this field define the number of depth texture samples that Unity takes when computing the normals. Low: 1 sample, Medium: 5 samples, High: 9 samples.");

			public static GUIContent Intensity =
				EditorGUIUtility.TrTextContent("Intensity", "The degree of darkness that Ambient Occlusion adds.");

			public static GUIContent DirectLightingStrength = EditorGUIUtility.TrTextContent("Direct Lighting Strength",
				"Controls how much the ambient occlusion affects direct lighting.");

			public static GUIContent Radius = EditorGUIUtility.TrTextContent("Radius",
				"The radius around a given point, where Unity calculates and applies the effect.");

			public static GUIContent SampleCount = EditorGUIUtility.TrTextContent("Sample Count",
				"The number of samples that Unity takes when calculating the obscurance value. Higher values have high performance impact.");
		}

		private void Init()
		{
			SerializedProperty settings = serializedObject.FindProperty("settings");
			m_Source = settings.FindPropertyRelative("source");
			m_Downsample = settings.FindPropertyRelative("downsample");
			m_NormalQuality = settings.FindPropertyRelative("normalSamples");
			m_Intensity = settings.FindPropertyRelative("intensity");
			m_DirectLightingStrength = settings.FindPropertyRelative("directLightStrength");
			m_Radius = settings.FindPropertyRelative("radius");
			m_SampleCount = settings.FindPropertyRelative("sampleCount");
			m_IsInitialized = true;
		}

		public override void OnInspectorGUI()
		{
			if (!m_IsInitialized)
			{
				Init();
			}

			EditorGUILayout.PropertyField(m_Downsample, Styles.Downsample);
			EditorGUILayout.PropertyField(m_Source, Styles.Source);

			//只有在enable depth 的  才能进行选择
			GUI.enabled = m_Source.enumValueIndex == (int) SSAOFeature.SSAOSettings.DepthSource.Depth;
			EditorGUILayout.PropertyField(m_NormalQuality, Styles.NormalQuality);
			GUI.enabled = true;

			m_Intensity.floatValue = EditorGUILayout.Slider(Styles.Intensity, m_Intensity.floatValue, 0f, 10f);
			m_DirectLightingStrength.floatValue = EditorGUILayout.Slider(Styles.DirectLightingStrength,
				m_DirectLightingStrength.floatValue, 0f, 1f);

			EditorGUILayout.PropertyField(m_Radius, Styles.Radius);
			m_Radius.floatValue = Mathf.Max(m_Radius.floatValue, 0f, m_Radius.floatValue);
			m_SampleCount.intValue = EditorGUILayout.IntSlider(Styles.SampleCount, m_SampleCount.intValue, 4, 20);
		}
	}
}