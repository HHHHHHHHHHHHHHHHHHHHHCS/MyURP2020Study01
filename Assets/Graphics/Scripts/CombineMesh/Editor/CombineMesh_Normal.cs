using System.Collections.Generic;
using System.Diagnostics;
using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;
using Unity.Profiling;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;

namespace Graphics.Scripts.CombineMesh.Editor
{
	//https://github.com/Unity-Technologies/MeshApiExamples
	public class CombineMesh_Normal
	{
		private static readonly ProfilerMarker smp1 = new ProfilerMarker("Find Meshes");
		private static readonly ProfilerMarker smp2 = new ProfilerMarker("Prepare");
		private static readonly ProfilerMarker smp3 = new ProfilerMarker("Create Mesh");
		private static readonly ProfilerMarker smp4 = new ProfilerMarker("Cleanup");


		//New API  2020.1
		[MenuItem("Mesh API Test/Create Mesh From Scene - New API %G")]
		public static void CreateMesh_MeshDataApi()
		{
			var sw = Stopwatch.StartNew();

			smp1.Begin();
			var meshFilters = Object.FindObjectsOfType<MeshFilter>();
			smp1.End();

			
			Material tempMat = null;

			smp2.Begin();
			var jobs = new CombineMeshJob();
			jobs.CreateInputArrays(meshFilters.Length);
			var inputMeshes = new List<Mesh>(meshFilters.Length);

			var vertexStart = 0;
			var indexStart = 0;
			var meshCount = 0;
			for (var i = 0; i < meshFilters.Length; i++)
			{
				var mf = meshFilters[i];
				var go = mf.gameObject;
				if (go.CompareTag("EditorOnly"))
				{
					Object.DestroyImmediate(go);
					continue;
				}

				if (tempMat == null)
				{
					tempMat = go.GetComponent<MeshRenderer>().material;
				}

				var mesh = mf.sharedMesh;
				inputMeshes.Add(mesh);
				jobs.vertexStart[meshCount] = vertexStart;
				jobs.indexStart[meshCount] = indexStart;
				jobs.xform[meshCount] = go.transform.localToWorldMatrix;
				vertexStart += mesh.vertexCount;
				indexStart += (int) mesh.GetIndexCount(0);
				jobs.bounds[meshCount] = new float3x2(new float3(Mathf.Infinity), new float3(Mathf.NegativeInfinity));
				meshCount++;
			}

			smp2.End();

			//acquire read-only data for input meshes
			jobs.meshData = Mesh.AcquireReadOnlyMeshData(inputMeshes);

			//create and initialize writable data for the output mesh
			//args must be 1
			//https://docs.unity3d.com/cn/2020.3/ScriptReference/Mesh.AllocateWritableMeshData.html
			var outputMeshData = Mesh.AllocateWritableMeshData(1);
			jobs.outputMesh = outputMeshData[0];
			jobs.outputMesh.SetIndexBufferParams(indexStart, IndexFormat.UInt32);
			jobs.outputMesh.SetVertexBufferParams(vertexStart,
				new VertexAttributeDescriptor(VertexAttribute.Position),
				new VertexAttributeDescriptor(VertexAttribute.Normal, stream: 1));

			var handle = jobs.Schedule(meshCount, 4);

			
			smp3.Begin();
			var newMesh = new Mesh();
			newMesh.name = "CombineMesh";
			var sm = new SubMeshDescriptor(0, indexStart, MeshTopology.Triangles)
			{
				firstVertex = 0, 
				vertexCount = vertexStart,
			};

			handle.Complete();

			var bounds = new float3x2(new float3(Mathf.Infinity), new float3(Mathf.NegativeInfinity));
			for (var i = 0; i < meshCount; i++)
			{
				var b = jobs.bounds[i];
				bounds.c0 = math.min(bounds.c0, b.c0);
				bounds.c1 = math.max(bounds.c1, b.c1);
			}

			sm.bounds = new Bounds((bounds.c0 + bounds.c1) * 0.5f, (bounds.c1 - bounds.c0));
			//mesh.RecalculateBounds(); //这个也可以生成bounds  不过我们这边用自己的
			jobs.outputMesh.subMeshCount = 1;
			//设置mesh 属性
			//DontRecalculateBounds 不自动生成bounds
			//DontValidateIndices 指示在使用 Mesh.SetIndexBufferData 修改网格数据时，Unity 不应检查索引
			//DontNotifyMeshUsers 修改网格的时候不通知修改mesh改变了
			jobs.outputMesh.SetSubMesh(0, sm,
				MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices |
				MeshUpdateFlags.DontNotifyMeshUsers);
			Mesh.ApplyAndDisposeWritableMeshData(outputMeshData, new[] {newMesh},
				MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices |
				MeshUpdateFlags.DontNotifyMeshUsers);
			newMesh.bounds = sm.bounds;
			smp3.End();

			
			smp4.Begin();
			jobs.meshData.Dispose();
			jobs.bounds.Dispose();
			smp4.End();
			
			// Create new GameObject with the new mesh
			var newGo = new GameObject("CombinedMesh");
			newGo.tag = "EditorOnly";
			var newMf = newGo.AddComponent<MeshFilter>();
			var newMr = newGo.AddComponent<MeshRenderer>();
			newMr.material = tempMat;
			newMf.sharedMesh = newMesh;
			//newMesh.RecalculateNormals(); // faster to do normal xform in the job
        
			var dur = sw.ElapsedMilliseconds;
			Debug.Log($"Took {dur/1000.0:F2}sec for {meshCount} objects, total {vertexStart} verts");
        
			Selection.activeObject = newGo;
		}

		[BurstCompile]
		private struct CombineMeshJob : IJobParallelFor
		{
			[ReadOnly] public Mesh.MeshDataArray meshData;
			public Mesh.MeshData outputMesh;

			[DeallocateOnJobCompletion, ReadOnly] public NativeArray<int> vertexStart;
			[DeallocateOnJobCompletion, ReadOnly] public NativeArray<int> indexStart;
			[DeallocateOnJobCompletion, ReadOnly] public NativeArray<float4x4> xform;
			public NativeArray<float3x2> bounds;

			public void CreateInputArrays(int meshCount)
			{
				vertexStart =
					new NativeArray<int>(meshCount, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
				indexStart = new NativeArray<int>(meshCount, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
				xform = new NativeArray<float4x4>(meshCount, Allocator.TempJob, NativeArrayOptions.UninitializedMemory);
				bounds = new NativeArray<float3x2>(meshCount, Allocator.TempJob,
					NativeArrayOptions.UninitializedMemory);
			}

			public void Execute(int index)
			{
			}
		}

		//Old API
		[MenuItem("Mesh API Test/Create Mesh From Scene - Old API %J")]
		public static void CreateMesh_OldAPI()
		{
			var sw = Stopwatch.StartNew();

			smp1.Begin();
			var meshFilters = Object.FindObjectsOfType<MeshFilter>();
			smp1.End();

			Material tempMat = null;

			smp2.Begin();
			List<Vector3> allVerts = new List<Vector3>();
			// List<Vector3> allNormals = new List<Vector3>(); //faster to do RecalculateNormals than doing it manually
			List<int> allIndices = new List<int>();
			foreach (var mf in meshFilters)
			{
				var go = mf.gameObject;
				if (go.CompareTag("EditorOnly"))
				{
					Object.DestroyImmediate(go);
					continue;
				}

				if (tempMat == null)
				{
					tempMat = go.GetComponent<MeshRenderer>().material;
				}

				var tr = go.transform;
				var mesh = mf.sharedMesh;
				var verts = mesh.vertices;
				//var normals = mesh.normals;
				var tris = mesh.triangles;

				for (var i = 0; i < verts.Length; i++)
				{
					var pos = verts[i];
					pos = tr.TransformPoint(pos);
					verts[i] = pos;
					//var nor = normals[i];
					//nor = tr.TransformDirection(nor).normalized;
					//normals[i] = nor;
				}

				var baseIdx = allVerts.Count;
				for (var i = 0; i < tris.Length; i++)
				{
					tris[i] = tris[i] + baseIdx;
				}

				allVerts.AddRange(verts);
				allIndices.AddRange(tris);

				go.SetActive(false);
			}

			smp2.End();

			smp3.Begin();
			var newMesh = new Mesh();
			newMesh.name = "CombinedMesh";
			newMesh.indexFormat = IndexFormat.UInt32;
			newMesh.SetVertices(allVerts);
			// newMesh.SetNormals(allNormals);
			newMesh.SetTriangles(allIndices, 0);
			newMesh.RecalculateNormals();
			smp3.End();

			var newGo = new GameObject("CombineMesh");
			newGo.tag = "EditorOnly";
			var newMF = newGo.AddComponent<MeshFilter>();
			var newMR = newGo.AddComponent<MeshRenderer>();
			newMR.material = tempMat;
			newMF.sharedMesh = newMesh;

			var dur = sw.ElapsedMilliseconds;
			Debug.Log($"Took {dur / 1000.0:F2}sec for {meshFilters.Length} objects, total {allVerts.Count} verts");

			Selection.activeObject = newGo;
		}
	}
}