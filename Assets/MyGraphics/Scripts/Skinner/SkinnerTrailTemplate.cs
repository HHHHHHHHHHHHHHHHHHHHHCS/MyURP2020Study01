using System.Collections.Generic;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerTrailTemplate : ScriptableObject
	{
		private const string k_tempMeshName = "Skinner Trail Template";

		[SerializeField] [Tooltip("Determines how long trails can remain (specified in frames).")]
		private int historyLength = 32;

		[SerializeField] private Mesh mesh;

		public int HistoryLength => historyLength;

		/// <summary>
		/// How many trail lines in the effect. 0xffff = 65535
		/// </summary>
		public int LineCount => 0xffff / (2 * historyLength);

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
			historyLength = Mathf.Clamp(historyLength, 4, 512);
		}


#if UNITY_EDITOR

		public void RebuildMesh()
		{
			mesh.Clear();

			var lcount = LineCount;

			var vertices = new List<Vector3>();

			for (int line = 0; line < lcount; line++)
			{
				var u = (line + 0.5f) / lcount;

				for (var seg = 0; seg < historyLength; seg++)
				{
					var v = (seg + 0.5f) / historyLength;
					vertices.Add(new Vector3(u, v, -0.5f));
					vertices.Add(new Vector3(u, v, +0.5f));
				}
			}

			mesh.SetVertices(vertices);

			var indices = new List<int>();

			int vi = 0;

			for (var line = 0; line < lcount; line++)
			{
				for (var seg = 0; seg < historyLength - 1; seg++)
				{
					indices.Add(vi + 0);
					indices.Add(vi + 2);
					indices.Add(vi + 1);

					indices.Add(vi + 1);
					indices.Add(vi + 2);
					indices.Add(vi + 3);

					vi += 2;
				}

				vi += 2;
			}

			mesh.SetIndices(indices, MeshTopology.Triangles, 0);

			//AABB大一点放置被culling掉
			mesh.bounds = new Bounds(Vector3.zero, Vector3.one*10);
			mesh.UploadMeshData(true);
		}
#endif
	}
}