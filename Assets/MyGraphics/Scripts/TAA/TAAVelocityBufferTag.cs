using System;
using System.Collections.Generic;
using UnityEngine;

namespace MyGraphics.Scripts.TAA
{
	//mesh filter 走material 替换
	public class TAAVelocityBufferTag : MonoBehaviour
	{
		[NonSerialized, HideInInspector] public Mesh mesh;
		[NonSerialized, HideInInspector] public Matrix4x4 localToWorldPrev;
		[NonSerialized, HideInInspector] public Matrix4x4 localToWorldCurr;

		// [NonSerialized, HideInInspector] public bool isSleeping;
		// private int framesNotRendered;

		[NonSerialized, HideInInspector] public bool useSkinnedMesh = false;
		private SkinnedMeshRenderer skinnedMesh = null;

		private void OnEnable()
		{
			if (useSkinnedMesh && mesh != null)
			{
				Destroy(mesh);
			}
			
			useSkinnedMesh = false;
			mesh = null;
			
			var smr = GetComponent<SkinnedMeshRenderer>();
			if (smr)
			{
				useSkinnedMesh = true;
				skinnedMesh = smr;
				mesh = new Mesh {name = this.name};
				skinnedMesh.BakeMesh(mesh);
			}
			else
			{
				var mf = GetComponent<MeshFilter>();
				if (mf == null)
				{
					enabled = false;
					return;
				}

				useSkinnedMesh = false;
				mesh = mf.sharedMesh;
			}

			localToWorldCurr = transform.localToWorldMatrix;
			localToWorldPrev = localToWorldCurr;
			
			TAAVelocityBufferRenderPass.activeObjects.Add(this);
		}

		private void OnDisable()
		{
			TAAVelocityBufferRenderPass.activeObjects.Remove(this);
		}

		private void LateUpdate()
		{
			UpdateVelocity();
		}

		private void UpdateVelocity()
		{
			//skinnedMesh 需要bake vertex position
			if (useSkinnedMesh)
			{
				var vs = mesh.vertices;
				skinnedMesh.BakeMesh(mesh);
				mesh.SetUVs(4, vs);
			}

			localToWorldPrev = localToWorldCurr;
			localToWorldCurr = transform.localToWorldMatrix;
		}
	}
}