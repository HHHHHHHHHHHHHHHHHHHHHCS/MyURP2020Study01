using System;
using UnityEngine;

namespace Graphics.Scripts.AreaLight
{
	[ExecuteInEditMode, RequireComponent(typeof(MeshRenderer), typeof(MeshFilter))]
	public partial class MyAreaLight : MonoBehaviour
	{
		private static Vector3[] vertices = new Vector3[4];


		public bool renderSource = true;
		public Vector3 size = new Vector3(1, 1, 2);
		[Range(0, 179)] public float angle = 0.0f;
		[MinValue(0)] public float intensity = 0.8f;
		public Color lightColor = Color.white;


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

			//UpdateSourceMesh();
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
			sourceMesh.hideFlags = HideFlags.HideAndDontSave;
			MeshFilter mfs = gameObject.GetComponent<MeshFilter>();
			mfs.sharedMesh = sourceMesh;

			Transform t = transform;
			if (t.localScale != Vector3.one)
			{
#if UNITY_EDITOR
				Debug.LogError("AreaLights don't like to be scaled. Setting local scale to 1.", this);
#endif
				t.localScale = Vector3.one;
			}

			SetupLUTs();

			props = new MaterialPropertyBlock();

			initialized = true;
			return false;
		}

		private void OnEnable()
		{
			if (!initialized)
			{
				return;
			}


			props.Clear();
			UpdateSourceMesh();
		}

		private void OnDisable()
		{
			if (Application.isPlaying == false)
			{
				Cleanup();
			}
			else
			{
				using var e = cameras.GetEnumerator();
				for (; e.MoveNext();)
				{
					e.Current.Value?.Clear();
				}
			}
		}

		private void Update()
		{
			if (!initialized)
			{
				return;
			}

			UpdateSourceMesh();

			if (Application.isPlaying)
			{
				using var e = cameras.GetEnumerator();
				for (; e.MoveNext();)
				{
					e.Current.Value?.Clear();
				}
			}
		}

		private void OnDestroy()
		{
			if (proxyMaterial != null)
			{
				DestroyImmediate(proxyMaterial);
			}

			if (sourceMesh != null)
			{
				DestroyImmediate(sourceMesh);
			}

			Cleanup();
		}

		private void OnWillRenderObject()
		{
			if (!initialized)
			{
				return;
			}

			Color color = new Color(
				Mathf.GammaToLinearSpace(lightColor.r),
				Mathf.GammaToLinearSpace(lightColor.g),
				Mathf.GammaToLinearSpace(lightColor.b),
				1.0f
			);
			
			//TODO:
		}


		private void UpdateSourceMesh()
		{
			size.x = Mathf.Max(size.x, 0);
			size.y = Mathf.Max(size.y, 0);
			size.z = Mathf.Max(size.z, 0);

			Vector2 quadSize = renderSource && enabled ? new Vector2(size.x, size.y) : new Vector2(0.0001f, 0.0001f);
			if (quadSize != currentQuadSize)
			{
				float x = quadSize.x * 0.5f;
				float y = quadSize.y * 0.5f;
				//稍微往后一点 阴影贴图用
				float z = -0.001f;

				vertices[0].Set(-x, y, z);
				vertices[1].Set(x, -y, z);
				vertices[2].Set(x, y, z);
				vertices[3].Set(-x, -y, z);

				sourceMesh.vertices = vertices;

				currentQuadSize = quadSize;
			}

			if (size != currentSize || angle != currentAngle)
			{
				sourceMesh.bounds = GetFrustumBounds();
			}
		}

		private Bounds GetFrustumBounds()
		{
			if (angle == 0.0f)
			{
				return new Bounds(Vector3.zero, size);
			}

			//near plane
			float tanHalfFov = Mathf.Tan(angle * 0.5f * Mathf.Deg2Rad);
			float near = size.y * 0.5f / tanHalfFov;
			float z = size.z;
			float y = (near + size.z) * tanHalfFov * 2.0f;
			float x = size.x * y / size.y;

			return new Bounds(Vector3.forward * size.z * 0.5f, new Vector3(x, y, z));
		}
	}
}