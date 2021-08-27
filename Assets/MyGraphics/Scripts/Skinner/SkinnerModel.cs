using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerModel : MonoBehaviour
	{
		[SerializeField] private int vertexCount;

		[SerializeField] private Mesh mesh;

		public int VertexCount => vertexCount;

		public Mesh Mesh => mesh;

		public void Initialize(Mesh source)
		{
			var inVertices = source.vertices;
			var inNormals = source.normals;
			var inTangents = source.tangents;
			var inBoneWeights = source.boneWeights;

			var outVertices = new List<Vector3>();
			var outNormals = new List<Vector3>();
			var outTangents = new List<Vector4>();
			var outBoneWeights = new List<BoneWeight>();

			for (var i = 0; i < inVertices.Length; i++)
			{
				if (outVertices.All(item => item != inVertices[i]))
				{
					outVertices.Add(inVertices[i]);
					outNormals.Add(inNormals[i]);
					outTangents.Add(inTangents[i]);
					outBoneWeights.Add(inBoneWeights[i]);
				}
			}

			var outUVs = Enumerable.Range(0, outVertices.Count)
				.Select(i => Vector2.right * (i + 0.5f) / outVertices.Count).ToList();

			var indices = Enumerable.Range(0, outVertices.Count).ToArray();

			mesh = Instantiate(source);
			//减去 (Copy)   加上_Skinner
			mesh.name = mesh.name.Substring(0, mesh.name.Length - 7)+"_Skinner";


			mesh.colors = null;
			mesh.uv2 = null;
			mesh.uv3 = null;
			mesh.uv4 = null;

			mesh.subMeshCount = 0;
			mesh.SetVertices(outVertices);
			mesh.SetNormals(outNormals);
			mesh.SetTangents(outTangents);
			mesh.SetUVs(0, outUVs);
			mesh.bindposes = source.bindposes;
			mesh.boneWeights = outBoneWeights.ToArray();

			mesh.subMeshCount = 1;
			mesh.SetIndices(indices, MeshTopology.Points, 0);
			mesh.UploadMeshData(true);

			vertexCount = outVertices.Count;
		}
	}
}