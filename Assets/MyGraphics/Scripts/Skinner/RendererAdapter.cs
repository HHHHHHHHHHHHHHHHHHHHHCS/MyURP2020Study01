using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	internal class RendererAdapter
	{
		private GameObject gameObject;
		private Material defaultMaterial;
		private MaterialPropertyBlock propertyBlock;

		public MaterialPropertyBlock PropertyBlock => propertyBlock;

		public RendererAdapter(GameObject _gameObject, Material _defaultMaterial)
		{
			gameObject = _gameObject;
			defaultMaterial = _defaultMaterial;
			propertyBlock = new MaterialPropertyBlock();
		}

		public void Update(Mesh templateMesh)
		{
			var meshFilter = gameObject.GetComponent<MeshFilter>();

			if (meshFilter == null)
			{
				meshFilter = gameObject.AddComponent<MeshFilter>();
				meshFilter.hideFlags = HideFlags.NotEditable;
			}

			if (meshFilter.sharedMesh != templateMesh)
			{
				meshFilter.sharedMesh = templateMesh;
			}

			var meshRenderer = gameObject.GetComponent<MeshRenderer>();

			if (meshRenderer.sharedMaterial == null)
			{
				meshRenderer.sharedMaterial = defaultMaterial;
			}

			meshRenderer.SetPropertyBlock(propertyBlock);
		}
	}
}