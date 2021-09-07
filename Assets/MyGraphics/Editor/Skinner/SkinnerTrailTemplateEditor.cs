using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	[CustomEditor(typeof(SkinnerTrailTemplate))]
	public class SkinnerTrailTemplateEditor : UnityEditor.Editor
	{
		private const string _helpText =
			"The Skinner Trail renderer tries to draw trail lines as many " +
			"as possible in a single draw call, and thus the number of " +
			"lines is automatically determined from the history length.";

		private SerializedProperty historyLength_ID;

		void OnEnable()
		{
			historyLength_ID = serializedObject.FindProperty("historyLength");
		}

		public override void OnInspectorGUI()
		{
			var template = (SkinnerTrailTemplate) target;

			serializedObject.Update();

			EditorGUI.BeginChangeCheck();
			EditorGUILayout.PropertyField(historyLength_ID);
			var rebuild = EditorGUI.EndChangeCheck();

			if (rebuild)
			{
				serializedObject.ApplyModifiedProperties();
			}

			EditorGUILayout.LabelField("Line Count", template.LineCount.ToString());
			EditorGUILayout.HelpBox(_helpText, MessageType.None);

			if (rebuild)
			{
				template.RebuildMesh();
			}
		}

		[MenuItem("Assets/Create/Skinner/Trail Template")]
		private static void CreateTemplateAsset()
		{
			ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateTemplateAssetAction>(),
				"New Skinner Trail Template.asset", null, null);
		}


		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
		internal class CreateTemplateAssetAction : EndNameEditAction
		{
			public override void Action(int instanceId, string pathName, string resourceFile)
			{
				var asset = CreateInstance<SkinnerTrailTemplate>();
				AssetDatabase.CreateAsset(asset, pathName);
				asset.RebuildMesh();

				AssetDatabase.AddObjectToAsset(asset.Mesh, asset);

				AssetDatabase.SaveAssets();
				AssetDatabase.Refresh();

				EditorUtility.FocusProjectWindow();
				Selection.activeObject = asset;
			}
		}
	}
}