using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.XR;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(SkinnedMeshRenderer))]
	public class SkinnerSource : MonoBehaviour
	{
		[SerializeField, Tooltip("Preprocessed model data.")]
		private SkinnerModel model;

		[SerializeField] private Material mat;

		private SkinnedMeshRenderer smr;

		private SkinnerVertexData data;

		public SkinnerVertexData Data => data;

		public SkinnerModel Model => model;

		public int Width => model == null ? 0 : model.VertexCount;
		public int Height => 1;

		public bool CanRender => mat != null && model != null;


		private void OnEnable()
		{
			if (!CanRender)
			{
				return;
			}
			
			smr = GetComponent<SkinnedMeshRenderer>();
			smr.receiveShadows = false;
			smr.sharedMesh =  model.Mesh;
			data = new SkinnerVertexData(smr, mat);
			SkinnerManager.Instance.Register(this);
		}

		private void OnDisable()
		{
			SkinnerManager.Instance.Remove(this);
		}
	}
}