using System;
using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	[CustomEditor(typeof(SkinnerParticleTemplate))]
	public class SkinnerParticleTemplateEditor : UnityEditor.Editor
	{
		private const string _helpText =
			"The Skinner Particle renderer draws all particles in a single " +
			"draw call, and thus the actual number of particle instances is " +
			"limited by the number of vertices in the particle shapes; it " +
			"may be less than the Max Instance Count.";

		private SerializedProperty shapes_ID;
		private SerializedProperty maxInstanceCount_ID;

		private void OnEnable()
		{
			shapes_ID = serializedObject.FindProperty("shapes");
			maxInstanceCount_ID = serializedObject.FindProperty("maxInstanceCount");
		}

		public override void OnInspectorGUI()
		{
			var template = (SkinnerParticleTemplate) target;

			serializedObject.Update();

			EditorGUI.BeginChangeCheck();
			EditorGUILayout.PropertyField(shapes_ID, true);
			EditorGUILayout.PropertyField(maxInstanceCount_ID);
			var rebuild = EditorGUI.EndChangeCheck();

			if (rebuild)
			{
				serializedObject.ApplyModifiedProperties();
			}

			EditorGUILayout.LabelField("Instance Count", template.InstanceCount.ToString());
			EditorGUILayout.HelpBox(_helpText, MessageType.None);

			rebuild |= GUILayout.Button("Rebuild");

			if (rebuild)
			{
				template.RebuildMesh();
			}
		}

		[MenuItem("Assets/Create/Skinner/Particle Template")]
		private static void CreateTemplateAsset()
		{
			ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateTemplateAssetAction>(),
				"New Skinner Particle Template.asset", null, null);
		}


		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
		internal class CreateTemplateAssetAction : EndNameEditAction
		{
			public override void Action(int instanceId, string pathName, string resourceFile)
			{
				var asset = CreateInstance<SkinnerParticleTemplate>();
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