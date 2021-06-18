using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Mathematics;
using UnityEngine;

namespace Graphics.Scripts.RayTracingGem
{
	public class GemManager : MonoBehaviour
	{
		private struct MeshObject
		{
			public Matrix4x4 localToWorldMatrix;
			public int indicesOffset;
			public int indicesCount;
		}

		private static readonly int MeshObjects_ID = Shader.PropertyToID("_MeshObjects");
		private static readonly int Vertices_ID = Shader.PropertyToID("_Vertices");
		private static readonly int Indices_ID = Shader.PropertyToID("_Indices");
		private static readonly int MeshIndex_ID = Shader.PropertyToID("_MeshIndex");

		private static GemManager _instance;

		public static GemManager Instance
		{
			get
			{
				if (_instance == null)
				{
					FindObjectOfType<GemManager>()?.Init();
				}

				return _instance;
			}
		}

		private List<GemObject> gemObjects;
		private List<MeshObject> meshObjects;
		private List<Vector3> vertices;
		private List<int> indices;

		private List<Transform> transformsToWatch;
		private bool meshObjectsNeedRebuilding;

		private ComputeBuffer meshObjectBuffer;
		private ComputeBuffer vertexBuffer;
		private ComputeBuffer indexBuffer;

		private MaterialPropertyBlock mpb;


		private void Awake()
		{
			Init();
		}

		//GemObject 的 OnEnable 可能在  GemManager的Awake之前
		//但是又懒得加调整顺序   所以直接单例FindObjectOfType
		private void Init()
		{
			if (_instance != null)
			{
				return;
			}

			_instance = this;
			mpb = new MaterialPropertyBlock();

			meshObjectsNeedRebuilding = true;

			gemObjects = new List<GemObject>();
			meshObjects = new List<MeshObject>();
			vertices = new List<Vector3>();
			indices = new List<int>();
			transformsToWatch = new List<Transform>();
		}

		private void Update()
		{
			if (Input.GetKeyDown(KeyCode.F12))
			{
				ScreenCapture.CaptureScreenshot("Screenshot/" + Time.time + ".png");
			}

			foreach (var trans in transformsToWatch)
			{
				if (trans.hasChanged)
				{
					meshObjectsNeedRebuilding = true;
					trans.hasChanged = false;
				}
			}

			if (meshObjectsNeedRebuilding)
			{
				BuildMeshObjectBuffers();
				SetMaterialParameters();
				meshObjectsNeedRebuilding = false;
			}
		}

		public void RegisterGem(GemObject gem)
		{
			gemObjects.Add(gem);
			transformsToWatch.Add(gem.transform);
			meshObjectsNeedRebuilding = true;
		}

		public void UnregisterGem(GemObject gem)
		{
			gemObjects.Remove(gem);
			transformsToWatch.Remove(gem.transform);
			meshObjectsNeedRebuilding = true;
		}

		private void BuildMeshObjectBuffers()
		{
			//clear all list data
			meshObjects.Clear();
			vertices.Clear();
			indices.Clear();

			foreach (var gem in gemObjects)
			{
				MeshFilter filter = gem.GetComponent<MeshFilter>();
				Mesh mesh = filter.sharedMesh;

				//Add vertex data
				int firstVertex = vertices.Count;
				vertices.AddRange(mesh.vertices);

				//Add index data
				//if the vertex buffer wasn't empty before
				//the indices need to be offfset
				int firstIndex = indices.Count;
				var _indices = mesh.GetIndices(0);
				indices.AddRange(_indices.Select(idx => idx + firstVertex));

				meshObjects.Add(new MeshObject()
				{
					localToWorldMatrix = gem.transform.localToWorldMatrix,
					indicesOffset = firstIndex,
					indicesCount = _indices.Length
				});
			}

			CreateComputeBuffer(ref meshObjectBuffer, meshObjects, 72); //16*4+4+4
			CreateComputeBuffer(ref vertexBuffer, vertices, 12); //3*4
			CreateComputeBuffer(ref indexBuffer, indices, 4); //1*4
		}

		private void CreateComputeBuffer<T>(ref ComputeBuffer buffer, List<T> data, int stride)
			where T : struct
		{
			//if buffer doesn't match the given criteria, release it
			if (buffer != null)
			{
				if (data.Count == 0 || buffer.count != data.Count || buffer.stride != stride)
				{
					buffer.Release();
					buffer = null;
				}
			}

			if (data.Count != 0)
			{
				if (buffer == null)
				{
					buffer = new ComputeBuffer(data.Count, stride);
				}

				buffer.SetData(data);
			}
		}

		private void SetMaterialParameters()
		{
			for (int i = 0; i < gemObjects.Count; i++)
			{
				GemObject gem = gemObjects[i];

				MeshRenderer renderer = gem.GetComponent<MeshRenderer>();
				Material material = renderer.sharedMaterial;

				material.SetBuffer(MeshObjects_ID, meshObjectBuffer);
				material.SetBuffer(Vertices_ID, vertexBuffer);
				material.SetBuffer(Indices_ID, indexBuffer);

				// mpb.Clear();
				renderer.GetPropertyBlock(mpb);
				mpb.SetInt(MeshIndex_ID, i);
				renderer.SetPropertyBlock(mpb);
			}
		}
	}
}