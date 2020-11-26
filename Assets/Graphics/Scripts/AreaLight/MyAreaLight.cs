using System;
using UnityEngine;

namespace Graphics.Scripts.AreaLight
{
	[ExecuteInEditMode, RequireComponent(typeof(MeshRenderer), typeof(MeshFilter))]
	public partial class MyAreaLight : MonoBehaviour
	{
		public bool renderSource = true;
		public Vector3 size = new Vector3(1, 1, 2);
		[Range(0, 179)] public float angle = 0.0f;
		[MinValue(0)] public float intensity = 0.8f;
		public Color color = Color.white;


		[Header("Shadows")] public bool shadows = false;
		public LayerMask shadowCullingMask = ~0;
		public TextureSize shadowmapRes = TextureSize.x2048;
		[MinValue(0)] public float receiverSearchDistance = 24.0f;
		[MinValue(0)] public float receiverDistanceScale = 5.0f;
		[MinValue(0)] public float lightNearSize = 4.0f;
		[MinValue(0)] public float lightFarSize = 22.0f;
		[Range(0f, 0.1f)] public float shadowBias = 0.001f;

		[HideInInspector] public Mesh quadMesh;

		private bool initialized = false;
		private MaterialPropertyBlock props;
		private MeshRenderer sourceRenderer;
		private Mesh sourceMesh;
		private Vector2 currentQuadSize = Vector2.zero;
		private Vector3 currentSize = Vector3.zero;
		private float currentAngle = -1.0f;

		private void Awake()
		{
			if (!Init())
			{
				return;
			}

			UpdateSourceMesh();
		}

		private bool Init()
		{
			if (initialized)
			{
				return true;
			}

			if (quadMesh == null || !InitDirect())
			{
				return false;
			}

			sourceRenderer = GetComponent<MeshRenderer>();
			sourceRenderer.enabled = true;
			sourceMesh = Instantiate(quadMesh);
			
			//TODO:

			return false;
		}

		private bool InitDirect()
		{
			throw new NotImplementedException();
		}


		private void UpdateSourceMesh()
		{
			throw new NotImplementedException();
		}
	}
}