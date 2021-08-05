using MyGraphics.Scripts.IrradianceVolume;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace MyGraphics.Editor.IrradianceVolume
{
	[CustomEditor(typeof(ProbeMgr))]
	public class ProbeMgrEditor : UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			DrawDefaultInspector();

			if (GUILayout.Button("Bake"))
			{
				var mgr = this.target as ProbeMgr;
				mgr.Bake();

				EditorSceneManager.SaveOpenScenes();
			}
		}
	}
}