using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace MyGraphics.Editor.GPUDrivenTerrain
{
	public class TerrainEditorUtil
	{
		public static string GetSelectedDir()
		{
			const string defaultPath = "Assets";
			var objs = Selection.GetFiltered<UnityEngine.Object>(SelectionMode.Assets);
			if (objs == null || objs.Length == 0)
			{
				return defaultPath;
			}

			//可以用下面这个判断
			// if (Selection.assetGUIDs.Length > 0)
			// {
			// 	
			// }

			//也可以用下面这个
			var path = AssetDatabase.GetAssetPath(objs[0]);
			if (string.IsNullOrEmpty(path))
			{
				return defaultPath;
			}

			return path;
		}

		[MenuItem("Assets/Create/GPUDrivenTerrain/CreatePlaneMesh")]
		public static void CreatePlaneMeshAsset()
		{
			var mesh = Scripts.GPUDrivenTerrain.MeshUtility.CreatePlaneMesh(16);
			string path = GetSelectedDir();
			path += "/Plane.mesh";
			AssetDatabase.CreateAsset(mesh, path);
			AssetDatabase.Refresh();
		}

		[MenuItem("Assets/Create/GPUDrivenTerrain/GenerateNormalMapFromHeightMap")]
		public static void GenerateNormalMapFromHeightMap()
		{
			if (Selection.activeObject is Texture2D heightMap)
			{
				GenerateNormalMapFromHeightMap(heightMap, (normalMap) => { });
			}
			else
			{
				Debug.LogWarning("必须选中Texture2D");
			}
		}


		public static void GenerateNormalMapFromHeightMap(Texture2D heightMap, Action<Texture2D> callback)
		{
			var rtdesc = new RenderTextureDescriptor(heightMap.width, heightMap.height, RenderTextureFormat.RG32)
			{
				enableRandomWrite = true
			};
			var rt = RenderTexture.GetTemporary(rtdesc);
			ComputeShader computeShader =
				AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/MyGraphics/Shaders/GPUDrivenTerrain/HeightToNormal.compute");
			computeShader.SetTexture(0, Shader.PropertyToID("HeightTex"), heightMap, 0);
			computeShader.SetTexture(0, Shader.PropertyToID("NormalTex"), rt, 0);
			uint tx, ty, tz;
			computeShader.GetKernelThreadGroupSizes(0, out tx, out ty, out tz);
			// computeShader.SetVector("TexSize", new Vector4(heightMap.width, heightMap.height, 0, 0));
			// computeShader.SetVector("WorldSize", new Vector3(10240, 2048, 10240));
			computeShader.Dispatch(0, (int) (heightMap.width / tx), (int) (heightMap.height / ty), 1);
			var req = AsyncGPUReadback.Request(rt, 0, 0, rt.width, 0, rt.height, 0, 1, (res) =>
			{
				if (res.hasError)
				{
					Debug.LogError("error");
				}
				else
				{
					Debug.Log("success");
					SaveRenderTextureTo(rt, "Assets/GPUDrivenTerrain/Textures/TerrainNormal.png");
				}

				RenderTexture.ReleaseTemporary(rt);
				callback(null);
			});
			UpdateGPUAsyncRequest(req);
		}


		public static void UpdateGPUAsyncRequest(AsyncGPUReadbackRequest req)
		{
			EditorApplication.CallbackFunction callUpdate = null;
			callUpdate = () =>
			{
				if (req.done)
				{
					// EditorApplication.delayCall -= callUpdate;
					return;
				}
				
				EditorApplication.delayCall += callUpdate;
				req.Update();
			};
			callUpdate();
		}

		public static Texture2D ConvertToTexture2D(RenderTexture renderTexture, TextureFormat format)
		{
			var original = RenderTexture.active;
			RenderTexture.active = renderTexture;
			var tex = new Texture2D(renderTexture.width, renderTexture.height, format, 0, false)
			{
				filterMode = renderTexture.filterMode
			};
			tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0, false);
			tex.Apply(false, false);
			RenderTexture.active = original;
			return tex;
		}

		public static void SaveRenderTextureTo(RenderTexture renderTexture, string path)
		{
			var tex = ConvertToTexture2D(renderTexture, TextureFormat.ARGB32);
			var bytes = tex.EncodeToPNG();
			System.IO.File.WriteAllBytes(path, bytes);
			AssetDatabase.Refresh();
			Object.DestroyImmediate(tex);
		}
	}
}