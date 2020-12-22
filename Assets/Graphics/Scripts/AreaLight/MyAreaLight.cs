using System;
using UnityEngine;

namespace Graphics.Scripts.AreaLight
{
	//因为要延迟渲染  所以放弃了
	//Copy by https://github.com/Unity-Technologies/VolumetricLighting
	[ExecuteInEditMode, RequireComponent(typeof(MeshRenderer), typeof(MeshFilter))]
	public partial class MyAreaLight : MonoBehaviour
	{
		private static Vector3[] vertices = new Vector3[4];

		public bool renderSource = true;
		public Vector3 size = new Vector3(1, 1, 2);
		[Range(0, 179)] public float angle = 0.0f;
		[MinValue(0)] public float intensity = 0.8f;
		public Color lightColor = Color.white;


		[Header("Shadows")] public bool enableShadows = false;
		public LayerMask shadowCullingMask = ~0;
		public TextureSize shadowmapRes = TextureSize.x2048;
		[MinValue(0)] public float receiverSearchDistance = 24.0f;
		[MinValue(0)] public float receiverDistanceScale = 5.0f;
		[MinValue(0)] public float lightNearSize = 4.0f;
		[MinValue(0)] public float lightFarSize = 22.0f;
		[Range(0f, 0.1f)] public float shadowBias = 0.001f;

		public Mesh quadMesh;

		private bool initialized = false;
		private MaterialPropertyBlock props;
		private MeshRenderer sourceRenderer;
		private Mesh sourceMesh;
		private Vector2 currentQuadSize = Vector2.zero;
		private Vector3 currentSize = Vector3.zero;
		private float currentAngle = -1.0f;

		private void Awake()
		{
			Debug.LogError("有问题,暂时弃坑这个先!!!");
			return;
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

			props.SetVector("_EmissionColor", GetColor());
			sourceRenderer.SetPropertyBlock(props);

			
			SetupCommandBuffer();
		}

		private void OnDrawGizmosSelected()
		{
			Gizmos.color = Color.white;

			if (angle == 0.0f)
			{
				Gizmos.matrix = transform.localToWorldMatrix;
				Gizmos.DrawWireCube(new Vector3(0, 0, 0.5f * size.z), size);
				Gizmos.matrix = Matrix4x4.identity;
				return;
			}

			float near = GetNearToCenter();
			Gizmos.matrix = transform.localToWorldMatrix * GetOffsetMatrix(-near); //去掉near clip

			Gizmos.DrawFrustum(Vector3.zero, angle, near + size.z, near, size.x / size.y);
			
			Gizmos.matrix = transform.localToWorldMatrix;
			Gizmos.color = Color.yellow;
			Bounds bounds = GetFrustumBounds();
			Gizmos.DrawWireCube(bounds.center, bounds.size);
			
			
			Gizmos.matrix = Matrix4x4.identity;
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

			//near = y / tanhalf
			//size.z 存的是 far - near
			//farY = (near+size.z)*tanhalf
			float tanHalfFov = Mathf.Tan(angle * 0.5f * Mathf.Deg2Rad);
			float near = size.y * 0.5f / tanHalfFov;
			float z = size.z;
			float y = (near + size.z) * tanHalfFov * 2.0f;
			float x = size.x * y / size.y;

			return new Bounds(Vector3.forward * size.z * 0.5f, new Vector3(x, y, z));
		}


		public Matrix4x4 GetProjectionMatrix(bool linearZ = false)
		{
			Matrix4x4 m;

			if (angle == 0.0f)
			{
				//z 翻转
				m = Matrix4x4.Ortho(-0.5f * size.x, 0.5f * size.x, -0.5f * size.y, 0.5f * size.y, 0, -size.z);
			}
			else
			{
				float near = GetNearToCenter();
				if (linearZ)
				{
					m = PerspectiveLinearZ(angle, size.x / size.y, near, near + size.z);
				}
				else
				{
					m = Matrix4x4.Perspective(angle, size.x / size.y, near, near + size.z);
					//Z翻转
					m = m * Matrix4x4.Scale(new Vector3(1, 1, -1));
				}

				//做点小偏移  在near内的不渲染
				m = m * GetOffsetMatrix(near);
			}

			//area light  vp  需要Z翻转
			return m * transform.worldToLocalMatrix;
		}

		private float GetNearToCenter()
		{
			if (angle == 0.0f)
			{
				return 0;
			}

			return size.y * 0.5f / Mathf.Tan(angle * 0.5f * Mathf.Deg2Rad);
		}


		private Matrix4x4 PerspectiveLinearZ(float fov, float aspect, float near, float far)
		{
			// A vector transformed with this matrix should get perspective division on x and y only:
			// Vector4 vClip = MultiplyPoint(PerspectiveLinearZ(...), vEye);
			// Vector3 vNDC = Vector3(vClip.x / vClip.w, vClip.y / vClip.w, vClip.z);
			// vNDC is [-1, 1]^3 and z is linear, i.e. z = 0 is half way between near and far in world space.

			//linear projection Matrix 注意这里z已经反转了

			float rad = Mathf.Deg2Rad * fov * 0.5f;
			float cotan = Mathf.Cos(rad) / Mathf.Sin(rad);
			float deltainv = 1.0f / (far - near);
			Matrix4x4 m;

			m.m00 = cotan / aspect;
			m.m01 = 0.0f;
			m.m02 = 0.0f;
			m.m03 = 0.0f;
			m.m10 = 0.0f;
			m.m11 = cotan;
			m.m12 = 0.0f;
			m.m13 = 0.0f;
			m.m20 = 0.0f;
			m.m21 = 0.0f;
			m.m22 = 2.0f * deltainv;
			m.m23 = -(far + near) * deltainv;
			m.m30 = 0.0f;
			m.m31 = 0.0f;
			m.m32 = 1.0f;
			m.m33 = 0.0f;

			return m;
		}

		private Matrix4x4 GetOffsetMatrix(float zOffset)
		{
			Matrix4x4 m = Matrix4x4.identity;
			m.SetColumn(3, new Vector4(0, 0, zOffset, 1));
			return m;
		}
	}
}