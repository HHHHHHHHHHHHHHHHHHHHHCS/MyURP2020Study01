using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerGlitchTemplate : ScriptableObject
	{
		private const string k_tempMeshName = "Skinner Glitch Template";
		private const int k_vcount = (65536 / 3) * 3;

		[SerializeField] private Mesh mesh;

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

#if UNITY_EDITOR

		public void RebuildMesh()
		{
			mesh.Clear();

			//fill the vertex array with zero
			mesh.vertices = new Vector3[k_vcount];

			// Hashed texcoord array
			// .x = hash of the current vertex
			// .y = hash of the left-hand neighbor vertex
			// .z = hash of the right-hand neighbor vertex
			// .w = common hash of the triangle
			var uvs = new List<Vector4>();
			for (var i = 0; i < k_vcount; i += 3)
			{
				float u0 = Random.value;
				float u1 = Random.value;
				float u2 = Random.value;
				float u3 = Random.value;
				uvs.Add(new Vector4(u0, u1, u2, u3));
				uvs.Add(new Vector4(u1, u2, u0, u3));
				uvs.Add(new Vector4(u2, u0, u1, u3));
			}

			mesh.SetUVs(0, uvs);

			mesh.SetIndices(Enumerable.Range(0, k_vcount).ToArray()
				, MeshTopology.Triangles, 0);

			mesh.bounds = new Bounds(Vector3.zero, Vector3.one);
			mesh.UploadMeshData(true);
		}

#endif
	}
}