using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using Object = UnityEngine.Object;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerParticleTemplate : ScriptableObject
	{
		private const string k_tempMeshName = "Skinner Particle Template";

		[SerializeField, Tooltip("List of meshes of particle shapes.")]
		private Mesh[] shapes = new Mesh[1];

		[SerializeField, Tooltip("Maximum number of particle instances.")]
		private int maxInstanceCount = 8192;

		[SerializeField] private int instanceCount;

		[SerializeField] private Mesh mesh;

		//可以在脚本上  添加默认值 
		[SerializeField] private Mesh defaultShape;

		public Mesh[] Shapes => shapes;

		public int MaxInstanceCount => maxInstanceCount;

		public int InstanceCount => instanceCount;

		public Mesh Mesh => mesh;


		private void OnEnable()
		{
			if (mesh == null)
			{
				mesh = new Mesh
				{
					name = k_tempMeshName
				};
			}
		}

		private void OnValidate()
		{
			maxInstanceCount = Mathf.Clamp(maxInstanceCount, 4, 8192);
		}

		private Mesh GetShape(int index)
		{
			if (shapes == null || shapes.Length == 0)
			{
				return defaultShape;
			}

			var temp = shapes[index % shapes.Length];
			return temp == null ? defaultShape : temp;
		}


#if UNITY_EDITOR

		public void RebuildMesh()
		{
			if (shapes == null || shapes.All(x => x == null))
			{
				return;
			}

			var vtx_out = new List<Vector3>();
			var nrm_out = new List<Vector3>();
			var tan_out = new List<Vector4>();
			var uv0_out = new List<Vector2>();
			var uv1_out = new List<Vector2>();
			var idx_out = new List<int>();

			var vertexCount = 0;
			instanceCount = 0;

			// Vector3 maxP = Vector3.negativeInfinity, minP = Vector3.positiveInfinity;
			// Push the source shapes one by one into the temporary array.
			while (instanceCount < maxInstanceCount)
			{
				// Get the N-th Source mesh.
				var mesh = GetShape(instanceCount);
				if (mesh == null)
				{
					instanceCount++;
					continue;
				}

				var vtx_in = mesh.vertices;

				// Keep the vertex count under 64k.
				if (vertexCount + vtx_in.Length > 65535)
				{
					break;
				}

				// foreach (var item in vtx_in)
				// {
				// 	maxP = Vector3.Max(maxP, item);
				// 	minP = Vector3.Min(minP, item);
				// }

				// Copy the vertices.
				vtx_out.AddRange(vtx_in);
				nrm_out.AddRange(mesh.normals);
				tan_out.AddRange(mesh.tangents);
				uv0_out.AddRange(mesh.uv);

				// Set UV1 temporarily.
				var uv1 = new Vector2(instanceCount + 0.5f, 0);
				uv1_out.AddRange(Enumerable.Repeat(uv1, vtx_in.Length));

				// Copy the indices.
				idx_out.AddRange(mesh.triangles.Select(i => i + vertexCount));

				// Increment the vertex/instance count.
				vertexCount += vtx_in.Length;
				instanceCount++;
			}

			if (vtx_out.Count == 0)
			{
				Debug.Log("All input mesh is null!");
				return;
			}

			// Rescale the UV1.
			uv1_out = uv1_out.Select(x => x / instanceCount).ToList();

			// Rebuild the mesh asset.
			mesh.Clear();
			mesh.SetVertices(vtx_out);
			mesh.SetNormals(nrm_out);
			mesh.SetUVs(0, uv0_out);
			mesh.SetUVs(1, uv1_out);
			mesh.SetIndices(idx_out.ToArray(), MeshTopology.Triangles, 0);
			mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 10);
			mesh.UploadMeshData(true);
		}
#endif
	}
}