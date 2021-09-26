using System.Collections.Generic;
using System.IO;
using System.Linq;
using Autodesk.Fbx;
using MyGraphics.Scripts.Skinner;
using UnityEditor;
using UnityEditor.Formats.Fbx.Exporter;
using UnityEngine;

namespace MyGraphics.Editor.Skinner
{
	public class SkinnerModelExportFBX : UnityEditor.Editor
	{
		private static SkinnerModel[] SelectedSkinnerModels
		{
			get
			{
				var assets = Selection.GetFiltered(typeof(SkinnerModel), SelectionMode.Deep);
				return assets.Select(x => (SkinnerModel) x).ToArray();
			}
		}


		[MenuItem("Assets/Skinner/Export Mesh", true)]
		private static bool ValidateAssets()
		{
			return SelectedSkinnerModels.Length > 0;
		}

		[MenuItem("Assets/Skinner/Export Mesh")]
		private static void ConvertAssets()
		{
			foreach (var item in SelectedSkinnerModels)
			{
				var source = item.Mesh;

				var dirPath = Path.GetDirectoryName(AssetDatabase.GetAssetPath(item));
				// var meshPath = AssetDatabase.GenerateUniqueAssetPath(dirPath + "/" + source.name + ".asset");
				// var fbxPath = AssetDatabase.GenerateUniqueAssetPath(dirPath + "/" + source.name + ".fbx");

				GameObject go = new GameObject(source.name);

				Mesh mesh = Instantiate(source);
				go.hideFlags = HideFlags.DontSave;
				
				var indices = new int[source.vertexCount * 3];
				for (int i = 0; i < source.vertexCount; i++)
				{
					indices[3 * i + 0] = i;
					indices[3 * i + 1] = i;
					indices[3 * i + 2] = i;
				}

				mesh.SetIndices(indices, MeshTopology.Triangles, 0);
				mesh.UploadMeshData(true);

				var smr = go.AddComponent<SkinnedMeshRenderer>();
				smr.sharedMesh = mesh;

				
				// AssetDatabase.CreateAsset(mesh, meshPath);

				// ModelExporter.ExportObject(fbxPath, go);

				// ModelExporter.ExportObject(fbxPath, diskGO);
			}
		}
	}
}