using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.XR;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerSource : MonoBehaviour
	{
		private const string k_replaceTag = "Skinner";

		[SerializeField, Tooltip("Preprocessed model data.")]
		private SkinnerModel model;

		[SerializeField] private Shader replacementShader;
		[SerializeField] private Shader replacementShaderPosition;
		[SerializeField] private Shader replacementShaderNormal;
		[SerializeField] private Shader replacementShaderTangent;

		[SerializeField] private Material placeholderMaterial;

		private RenderTexture positionTex0;
		private RenderTexture positionTex1;
		private RenderTexture normalTex;
		private RenderTexture tangentTex;

		private RenderBuffer[] mrt0;
		private RenderBuffer[] mrt1;
		private bool swapFlag;

		private SkinnedMeshRenderer smr;
		private Camera camera;
		private int frameCount;

		public bool IsReady => frameCount > 1;

		/// Baked texture of skinned vertex positions.
		public RenderTexture PositionTex => swapFlag ? positionTex1 : positionTex0;

		/// Baked texture of skinned vertex positions from the previous frame.
		public RenderTexture PreviousPositionTex => swapFlag ? positionTex0 : positionTex1;

		/// Baked texture of skinned vertex normals.
		public RenderTexture NormalTex => normalTex;

		/// Baked texture of skinned vertex tangents.
		public RenderTexture TangentTex => tangentTex;

		private void Start()
		{
			smr = GetComponent<SkinnedMeshRenderer>();

			positionTex0 = CreateRT();
			positionTex1 = CreateRT();
			normalTex = CreateRT();
			tangentTex = CreateRT();

			mrt0 = new[]
			{
				positionTex0.colorBuffer,
				normalTex.colorBuffer,
				tangentTex.colorBuffer,
			};

			mrt1 = new[]
			{
				positionTex1.colorBuffer,
				normalTex.colorBuffer,
				tangentTex.colorBuffer,
			};

			OverrideRender();
			BuildCamera();
		}

		private void OnDestroy()
		{
			CoreUtils.Destroy(positionTex0);
			CoreUtils.Destroy(positionTex1);
			CoreUtils.Destroy(normalTex);
			CoreUtils.Destroy(tangentTex);
		}

		private void LateUpdate()
		{
			swapFlag = !swapFlag;

			if (!XRSettings.enabled)
			{
				if (swapFlag)
				{
					camera.SetTargetBuffers(mrt1, positionTex1.depthBuffer);
				}
				else
				{
					camera.SetTargetBuffers(mrt0, positionTex0.depthBuffer);
				}

				camera.RenderWithShader(replacementShader, k_replaceTag);
			}
			else if (swapFlag)
			{
				camera.targetTexture = positionTex1;
				camera.RenderWithShader(replacementShaderPosition, k_replaceTag);
				camera.targetTexture = normalTex;
				camera.RenderWithShader(replacementShaderNormal, k_replaceTag);
				camera.targetTexture = tangentTex;
				camera.RenderWithShader(replacementShaderTangent, k_replaceTag);
			}
			else
			{
				camera.targetTexture = positionTex0;
				camera.RenderWithShader(replacementShaderPosition, k_replaceTag);
				camera.targetTexture = normalTex;
				camera.RenderWithShader(replacementShaderNormal, k_replaceTag);
				camera.targetTexture = tangentTex;
				camera.RenderWithShader(replacementShaderTangent, k_replaceTag);
			}

			// We manually disable the skinned mesh renderer here because
			// there is a regression from 2017.1.0 that prevents
			// CallingStateController from being called in OnPostRender.
			// This is a pretty hackish workaround, so FIXME later.
			smr.enabled = false;

			frameCount++;
		}

		private RenderTexture CreateRT()
		{
			var format = RenderTextureFormat.ARGBFloat;
			var rt = new RenderTexture(model.VertexCount, 1, 0, format);
			rt.filterMode = FilterMode.Point;
			return rt;
		}

		private void OverrideRender()
		{
			var smr = GetComponent<SkinnedMeshRenderer>();
			smr.sharedMesh = model.Mesh;
			smr.material = placeholderMaterial;
			smr.receiveShadows = false;

			smr.enabled = false;
		}

		//create a camera for vertex baking
		private void BuildCamera()
		{
			var go = new GameObject("Camera");
			go.hideFlags = HideFlags.HideInInspector | HideFlags.HideAndDontSave;

			var tr = go.transform;
			tr.parent = transform;
			tr.localPosition = Vector3.zero;
			tr.localRotation = Quaternion.identity;


			camera = go.AddComponent<Camera>();
			camera.renderingPath = RenderingPath.Forward;
			camera.clearFlags = CameraClearFlags.SolidColor;
			camera.depth = -1000;

			camera.nearClipPlane = -100;
			camera.farClipPlane = 100;
			camera.orthographic = true;

			camera.enabled = false; //我们手动call render

			var culler = go.AddComponent<CullingStateController>();
			culler.target = GetComponent<SkinnedMeshRenderer>();
		}
	}
}