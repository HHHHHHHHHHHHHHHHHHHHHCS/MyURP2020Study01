using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.GPUOcclusionCulling
{
	public class HardwareOcclusion : MonoBehaviour
	{
		struct Cuboid
		{
			public Vector3 center;
			public Vector3 scale;
		};

		public GameObject[] targets;
		public Shader hardwareOcclusionShader;
		public ComputeShader intersectionShader;
		public bool isDynamic;
		public uint delay = 1;
		public bool debug = false;

		private Material material;
		private ComputeBuffer reader;
		private ComputeBuffer writer;
		private Vector4[] elements;
		private Vector4[] cache;
		private List<List<Renderer>> meshRenderers;
		private List<Vector4> vertices;

		private ComputeBuffer aabb;
		private ComputeBuffer intersection;
		private Cuboid[] cuboids;
		private int[] reset;
		private int cellIndex = -1;
		private Coroutine coroutine;


		private void Init()
		{
			if (material == null)
			{
				material = new Material(hardwareOcclusionShader);
			}

			meshRenderers = new List<List<Renderer>>();
			writer = new ComputeBuffer(targets.Length, 16, ComputeBufferType.Default);
			elements = new Vector4[targets.Length];
			cache = new Vector4[targets.Length];
			cuboids = new Cuboid[targets.Length];
			if (cache.Length > 0)
			{
				cache[0] = Vector4.one;
			}

			vertices = new List<Vector4>();
			Graphics.ClearRandomWriteTargets();
			Graphics.SetRandomWriteTarget(1, writer, false);
			for (int i = 0; i < targets.Length; i++)
			{
				meshRenderers.Add(targets[i].GetComponentsInChildren<Renderer>().ToList());
				Vector4[] aabb = GenerateCell(targets[i], i);
				cuboids[i].center = GetCenterFromCubeVertices(aabb);
				cuboids[i].scale = GetScaleFromCubeVertices(aabb);
				vertices.AddRange(aabb);
			}


			reader = new ComputeBuffer(vertices.Count, 16, ComputeBufferType.Default);
			reader.SetData(vertices.ToArray());
			material.SetBuffer("_Reader", reader);
			material.SetBuffer("_Writer", writer);
			material.SetInt("_Debug", debug ? 1 : 0);
			aabb = new ComputeBuffer(cuboids.Length, 24, ComputeBufferType.Default);
			intersectionShader.SetBuffer(0, "_AABB", aabb);
			intersectionShader.SetBuffer(0, "_Intersection", intersection);
			aabb.SetData(cuboids);
			reset = new int[1] {-1};
			coroutine = StartCoroutine(UpdateAsync());
		}

		private void OnEnable()
		{
			Init();
		}

		private void Update()
		{
			if (isDynamic)
			{
				GenerateMap();
			}

			if (Time.frameCount % delay != 0)
			{
				return;
			}

			writer.GetData(elements);
			bool state = ArrayState(elements, cache);
			if (!state)
			{
				for (int i = 0; i < meshRenderers.Count; i++)
				{
					for (int j = 0; j < meshRenderers[i].Count; j++)
					{
						if (i == cellIndex)
						{
							meshRenderers[i][j].enabled = true;
						}
						else
						{
							meshRenderers[i][j].enabled = Vector4.Dot(elements[i], elements[i]) > 0.0f;
						}
					}

					ArrayCopy(elements, cache);
				}

				System.Array.Clear(elements, 0, elements.Length);
				writer.SetData(elements);
			}
		}

		private void OnDisable()
		{
			StopCoroutine(coroutine);
			reader.Dispose();
			writer.Dispose();
			aabb.Dispose();
			intersection.Dispose();
			for (int i = 0; i < meshRenderers.Count; i++)
			{
				for (int j = 0; j < meshRenderers[i].Count; j++)
				{
					meshRenderers[i][j].enabled = true;
				}
			}
		}

		//TODO:改到SRP
		private void OnRenderObject()
		{
			material.SetPass(0);
			Graphics.DrawProceduralNow(MeshTopology.Triangles, vertices.Count, 1);
		}

		private IEnumerator UpdateAsync()
		{
			while (true)
			{
				Vector3 p = Camera.main.transform.position;
				intersectionShader.SetVector("_Point", new Vector4(p.x, p.y, p.z, 0.0f));
				intersection.SetData(reset);
				int threadGroupX = (int) Mathf.Ceil(cuboids.Length / 8.0f);
				intersectionShader.Dispatch(0, threadGroupX, 1, 1);
				AsyncGPUReadbackRequest request = AsyncGPUReadback.Request(intersection);
				yield return new WaitUntil(() => request.done);
				cellIndex = request.GetData<int>()[0];
			}
		}


		private static Vector3 GetCenterFromCubeVertices(Vector4[] verts)
		{
			Vector3 total = Vector3.zero;
			int length = verts.Length;
			foreach (var item in verts)
			{
				total += new Vector3(item.x, item.y, item.z);
			}

			return total / length;
		}

		private static Vector3 GetScaleFromCubeVertices(Vector4[] verts)
		{
			Vector3 min = Vector3.positiveInfinity;
			Vector3 max = Vector3.negativeInfinity;
			foreach (var item in verts)
			{
				Vector3 point = new Vector3(item.x, item.y, item.z);
				min = Vector3.Min(min, point);
				max = Vector3.Max(max, point);
			}

			return (max - min) * 0.5f;
		}

		//这里借助了API  其实完全没有必要可以自己写
		private static Vector4[] GenerateCell(GameObject parent, int index)
		{
			BoxCollider bc = parent.AddComponent<BoxCollider>();
			Bounds bounds = new Bounds(Vector3.zero, Vector3.zero);
			bool hasBounds = false;
			Renderer[] renderers = parent.GetComponentsInChildren<Renderer>();
			for (int i = 0; i < renderers.Length; i++)
			{
				if (hasBounds)
				{
					//自动扩大box  第一个不包括进去
					bounds.Encapsulate(renderers[i].bounds);
				}
				else
				{
					bounds = renderers[i].bounds;
					hasBounds = true;
				}
			}

			if (hasBounds)
			{
				bc.center = bounds.center - parent.transform.position;
				bc.size = bounds.size;
			}
			else
			{
				bc.size = Vector3.zero;
				bc.center = Vector3.zero;
			}

			bc.size = Vector3.Scale(bc.size, new Vector3(1.01f, 1.01f, 1.01f));
			GameObject cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
			cube.transform.position = parent.transform.position + bc.center;
			cube.transform.localScale = bc.size;
			Mesh mesh = cube.GetComponent<MeshFilter>().sharedMesh;
			Vector4[] vertices = new Vector4[mesh.triangles.Length];
			for (int i = 0; i < vertices.Length; i++)
			{
				Vector3 p = cube.transform.TransformPoint(mesh.vertices[mesh.triangles[i]]);
				vertices[i] = new Vector4(p.x, p.y, p.z, index);
			}

			Destroy(bc);
			Destroy(cube);
			return vertices;
		}


		private static bool ArrayState(Vector4[] a, Vector4[] b)
		{
			for (int i = 0; i < a.Length; i++)
			{
				bool x = Vector4.Dot(a[i], a[i]) > 0.0f;
				bool y = Vector4.Dot(b[i], b[i]) > 0.0f;
				if (x != y)
				{
					return false;
				}
			}

			return true;
		}

		private static void ArrayCopy(Vector4[] source, Vector4[] destination)
		{
			for (int i = 0; i < source.Length; i++)
			{
				destination[i] = source[i];
			}
		}

		private void GenerateMap()
		{
			vertices.Clear();
			vertices.TrimExcess();
			for (int i = 0; i < targets.Length; i++)
			{
				Vector4[] aabb = GenerateCell(targets[i], i);
				cuboids[i].center = GetCenterFromCubeVertices(aabb);
				cuboids[i].scale = GetScaleFromCubeVertices(aabb);
				vertices.AddRange(aabb);
			}

			reader.SetData(vertices.ToArray());
		}
	}
}