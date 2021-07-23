using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Editor.GPUDrivenTerrain
{
	public class QuadTreeMapEditorBuilder
	{
		private int _maxLodSize;
		private int _lodCount;
		private ComputeShader _computeShader;

		private ComputeShader computeShader
		{
			get
			{
				if (!_computeShader)
				{
					_computeShader =
						AssetDatabase.LoadAssetAtPath<ComputeShader>(
							"Assets/MyGraphics/Shaders/GPUDrivenTerrain/QuadTreeMipMapGen.compute");
				}

				return _computeShader;
			}
		}

		public QuadTreeMapEditorBuilder(int maxLodSize, int lodCount)
		{
			_maxLodSize = maxLodSize;
			_lodCount = lodCount;
		}

		private void BuildQuadTreeMapMip(int mip, int nodeIdOffset)
		{
			var mipTexSize = (int) (_maxLodSize * Mathf.Pow(2, this._lodCount - 1 - mip));
			var desc = new RenderTextureDescriptor(mipTexSize, mipTexSize, RenderTextureFormat.R16, 0, 1)
			{
				autoGenerateMips = false,
				enableRandomWrite = true
			};
			var rt = new RenderTexture(desc)
			{
				filterMode = FilterMode.Point
			};
			rt.Create();
			computeShader.SetTexture(0, "QuadTreeMap", rt);
			computeShader.SetInt("NodeIDOffset", nodeIdOffset);
			computeShader.SetInt("MapSize", mipTexSize);
			var group = (int) Mathf.Pow(2, this._lodCount - mip - 1);
			computeShader.Dispatch(0, group, group, 1);
			var req = AsyncGPUReadback.Request(rt, 0, 0, mipTexSize, 0, mipTexSize, 0, 1, TextureFormat.R16, (res) =>
			{
				if (res.hasError)
				{
					return;
				}
			
				var tex2D = TerrainEditorUtil.ConvertToTexture2D(rt, TextureFormat.R16);
				var bytes = tex2D.EncodeToPNG();
				var dir = TerrainEditorUtil.GetSelectedDir();
				System.IO.File.WriteAllBytes($"{dir}/QuadTreeMap_" + mip + ".png", bytes);
				Object.DestroyImmediate(rt);
				if (mip > 0)
				{
					BuildQuadTreeMapMip(mip - 1, nodeIdOffset + mipTexSize * mipTexSize);
				}
				else
				{
					AssetDatabase.Refresh();
				}
			});
			TerrainEditorUtil.UpdateGPUAsyncRequest(req);
		}

		public void BuildAsync()
		{
			BuildQuadTreeMapMip(_lodCount - 1, 0);
		}

		[MenuItem("Assets/Create/GPUDrivenTerrain/GenerateQuadTreeMipMaps")]
		public static void GenerateQuadTreeMipMaps()
		{
			new QuadTreeMapEditorBuilder(5, 6).BuildAsync();
		}
	}
}