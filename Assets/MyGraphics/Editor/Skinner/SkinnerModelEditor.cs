using System.Collections.Generic;
using System.IO;
using System.Linq;
using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	[CustomEditor(typeof(SkinnerModel))]
	public class SkinnerModelEditor : UnityEditor.Editor
	{
		private static Mesh[] SelectedMeshAssets
		{
			get
			{
				var assets = Selection.GetFiltered(typeof(Mesh), SelectionMode.Deep);
				return assets.Select(x => (Mesh) x).ToArray();
			}
		}

		public override void OnInspectorGUI()
		{
			var model = (SkinnerModel) target;
			EditorGUILayout.LabelField("Vertex Count", model.VertexCount.ToString());
		}

		private static bool CheckSkinned(Mesh mesh)
		{
			if (mesh.boneWeights.Length > 0)
			{
				return true;
			}

			Debug.LogError(
				"The given mesh (" + mesh.name + ") is not skinned. " +
				"Skinner only can handle skinned meshes."
			);
			return false;
		}


		[MenuItem("Assets/Skinner/Convert Mesh", true)]
		private static bool ValidateAssets()
		{
			return SelectedMeshAssets.Length > 0;
		}

		[MenuItem("Assets/Skinner/Convert Mesh")]
		private static void ConvertAssets()
		{
			var converted = new List<Object>();

			foreach (var item in SelectedMeshAssets)
			{
				if (!CheckSkinned(item))
				{
					continue;
				}

				var dirPath = Path.GetDirectoryName(AssetDatabase.GetAssetPath(item));
				var assetPath = AssetDatabase.GenerateUniqueAssetPath(dirPath + "/New Skinner Model.asset");

				var asset = CreateInstance<SkinnerModel>();
				asset.Initialize(item);
				AssetDatabase.CreateAsset(asset, assetPath);
				//把资源添加到现有的资源中  防止加载不到
				AssetDatabase.AddObjectToAsset(asset.Mesh, asset);

				converted.Add(asset);
			}
		}
	}
}