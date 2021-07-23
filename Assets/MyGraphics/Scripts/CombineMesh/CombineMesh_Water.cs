using System;
using System.Linq;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using UnityEngine;

namespace MyGraphics.Scripts.CombineMesh
{
	//https://github.com/Unity-Technologies/MeshApiExamples
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class CombineMesh_Water : MonoBehaviour
	{
		public bool useJobs;
		public float surfaceActualWidth = 10;
		public float surfaceActualHeight = 10;
		public int surfaceWidthPoints = 100;
		public int surfaceHeightPoints = 100;

		private Transform[] waveSources;
		private NativeArray<float3> waveSourcePositions;
		private NativeArray<float3> vertices;
		private Mesh mesh;
		private float localTime;

		private void OnEnable()
		{
			if (mesh != null)
			{
				DestroyImmediate(mesh);
			}

			mesh = CreateMesh();
			//linq  foreach transform
			waveSources = transform.Cast<Transform>().Where(t => t.gameObject.activeInHierarchy).ToArray();
			waveSourcePositions = new NativeArray<float3>(waveSources.Length, Allocator.Persistent,
				NativeArrayOptions.UninitializedMemory);
		}

		private void OnDisable()
		{
			waveSourcePositions.Dispose();
			vertices.Dispose();
		}

		private void Update()
		{
			localTime += 2.0f * Time.deltaTime;
			UpdateWaveSourcePositions();
			var job = new WaveJob()
				{vertices = this.vertices, waveSourcePositions = this.waveSourcePositions, time = localTime};
			if (!useJobs)
			{
				for (int i = 0; i < vertices.Length; i++)
				{
					job.Execute(i);
				}
			}
			else
			{
				job.Schedule(vertices.Length, 16).Complete();
			}

			mesh.SetVertices(vertices);
			mesh.RecalculateNormals();
		}

		private static float MapValue(float refValue, float refMin, float refMax, float targetMin, float targetMax)
		{
			return targetMin + (refValue - refMin) * (targetMax - targetMin) / (refMax - refMin);
		}

		private Mesh CreateMesh()
		{
			Mesh newMesh = new Mesh();
			newMesh.name = "WaterMesh";
			vertices = new NativeArray<float3>(surfaceWidthPoints * surfaceHeightPoints, Allocator.Persistent,
				NativeArrayOptions.UninitializedMemory);
			int width = surfaceWidthPoints - 1, height = surfaceHeightPoints - 1;
			var indices = new int[width * height * 6];
			var index = 0;
			for (var i = 0; i < surfaceWidthPoints; i++)
			{
				for (var j = 0; j < surfaceHeightPoints; j++)
				{
					float x = MapValue(i, 0.0f, width
						, -surfaceActualWidth / 2.0f, surfaceActualWidth / 2.0f);
					float z = MapValue(j, 0.0f, height
						, -surfaceActualHeight / 2.0f, surfaceActualHeight / 2.0f);
					vertices[index++] = new Vector3(x, 0, z);
				}
			}

			index = 0;
			for (var i = 0; i < width; i++)
			{
				for (var j = 0; j < height; j++)
				{
					var baseIndex = i * surfaceHeightPoints + j;
					indices[index++] = baseIndex;
					indices[index++] = baseIndex + 1;
					indices[index++] = baseIndex + surfaceHeightPoints + 1;
					indices[index++] = baseIndex;
					indices[index++] = baseIndex + surfaceHeightPoints + 1;
					indices[index++] = baseIndex + surfaceHeightPoints;
				}
			}

			newMesh.SetVertices(vertices);
			newMesh.triangles = indices;
			newMesh.RecalculateNormals();

			GetComponent<MeshFilter>().mesh = newMesh;

			return newMesh;
		}


		private void UpdateWaveSourcePositions()
		{
			for (var i = 0; i < waveSources.Length; i++)
			{
				waveSourcePositions[i] = waveSources[i].position;
			}
		}

		[BurstCompile]
		private struct WaveJob : IJobParallelFor
		{
			public NativeArray<float3> vertices;

			[ReadOnly, NativeDisableParallelForRestriction]
			public NativeArray<float3> waveSourcePositions;

			public float time;

			public void Execute(int index)
			{
				var p = vertices[index];
				var y = 0.0f;
				//burst 不方便支持foreach
				for (var i = 0; i < waveSourcePositions.Length; i++)
				{
					var p1 = p.xz;
					var p2 = waveSourcePositions[i].xz;
					var dist = Vector2.Distance(p1, p2);
					if (dist < 5f)
					{
						y += Mathf.Sin(dist * 12.0f - time) / (dist * 20 + 10);
					}
				}
				p.y = y;
				vertices[index] = p;
			}
		}
	}
}