using System.IO;
using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	[CustomEditor(typeof(SkinnerGlitchTemplate))]
	public class SkinnerGlitchTemplateEditor : UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			if (GUILayout.Button("Rebuild"))
			{
				(target as SkinnerGlitchTemplate)?.RebuildMesh();
			}
		}

		[MenuItem("Assets/Create/Skinner/Glitch Template")]
		private static void CreateTemplateAsset()
		{
			ProjectWindowUtil.StartNameEditingIfProjectWindowExists(0, CreateInstance<CreateTemplateAssetAction>(),
				"New Glitch Particle Template.asset", null, null);
		}


		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1812")]
		internal class CreateTemplateAssetAction : EndNameEditAction
		{
			public override void Action(int instanceId, string pathName, string resourceFile)
			{
				var asset = CreateInstance<SkinnerGlitchTemplate>();
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