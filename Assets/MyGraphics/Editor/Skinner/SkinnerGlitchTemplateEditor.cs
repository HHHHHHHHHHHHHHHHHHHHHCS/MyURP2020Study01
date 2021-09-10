using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	[CustomEditor(typeof(SkinnerGlitchTemplate))]
	public class SkinnerGlitchTemplateEditor : UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			// There is nothing to show!
		}

#if SHOW_CREATE_MENU_ITEM
        [MenuItem("Assets/Create/Skinner/Glitch Template")]
        public static void CreateTemplateAsset()
        {
            // Make a proper path from the current selection.
            var path = AssetDatabase.GetAssetPath(Selection.activeObject);
            if (string.IsNullOrEmpty(path))
                path = "Assets";
            else if (Path.GetExtension(path) != "")
                path = path.Replace(Path.GetFileName(path), "");
            var assetPathName = AssetDatabase.GenerateUniqueAssetPath(path + "/New Skinner Glitch Template.asset");

            // Create a template asset.
            var asset = ScriptableObject.CreateInstance<SkinnerGlitchTemplate>();
            AssetDatabase.CreateAsset(asset, assetPathName);
            AssetDatabase.AddObjectToAsset(asset.mesh, asset);

            // Build an initial mesh for the asset.
            asset.RebuildMesh();

            // Save the generated mesh asset.
            AssetDatabase.SaveAssets();

            // Tweak the selection.
            EditorUtility.FocusProjectWindow();
            Selection.activeObject = asset;
        }

#endif
	}
}