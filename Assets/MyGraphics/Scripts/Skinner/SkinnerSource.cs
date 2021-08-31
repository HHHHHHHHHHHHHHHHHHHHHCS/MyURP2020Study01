using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.XR;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(SkinnedMeshRenderer))]
	public class SkinnerSource : MonoBehaviour
	{
		public static SkinnerSource Instance { get; private set; }

		[SerializeField, Tooltip("Preprocessed model data.")]
		private SkinnerModel model;

		private SkinnedMeshRenderer smr;

		/// Baked texture of skinned vertex positions.
		public RenderTexture PositionTex => null;

		/// Baked texture of skinned vertex positions from the previous frame.
		public RenderTexture PreviousPositionTex => null;

		public SkinnerModel Model => model;

		private void OnEnable()
		{
			Instance = this;
			smr = GetComponent<SkinnedMeshRenderer>();

			if (model != null)
			{
				smr.sharedMesh = model.Mesh;
			}

			smr.receiveShadows = false;
		}

		private void OnDisable()
		{
			Instance = null;
		}
	}
}