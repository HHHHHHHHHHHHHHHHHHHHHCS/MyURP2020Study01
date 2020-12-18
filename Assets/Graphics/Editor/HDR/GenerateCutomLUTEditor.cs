using Graphics.Scripts.HDR;
using UnityEditor;
using UnityEngine;

namespace Graphics.Editor.HDR
{
	[CustomEditor(typeof(GenerateCutomLUT))]
	public class GenerateCutomLUTEditor : UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			DrawDefaultInspector();

			GenerateCutomLUT script = target as GenerateCutomLUT;
			if (GUILayout.Button("Generate"))
			{
				script.Generate();
				AssetDatabase.Refresh();
			}
		}
	}
}