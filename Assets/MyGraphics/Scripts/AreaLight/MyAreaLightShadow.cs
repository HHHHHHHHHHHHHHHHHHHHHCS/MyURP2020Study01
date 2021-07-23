using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.AreaLight
{
	public partial class MyAreaLight : MonoBehaviour
	{
		public enum TextureSize
		{
			x512 = 512,
			x1024 = 1024,
			x2048 = 2048,
			x4096 = 4096,
		}

		private const float c_maxDistance = 2048.0f;

		public Shader shadowmapShader;
		public Shader blurShadowmapShader;

		private Camera shadowmapCamera;
		private Transform shadowmapCameraTransform;


		private RenderTexture shadowmap;
		private RenderTexture blurredShadowmap = null;
		private Texture2D shadowmapDummy = null;


		private int shadowmapRenderTime = -1;

		private void SetupShadowmapForSampling(CommandBuffer cmd)
		{
			UpdateShadowmap((int) shadowmapRes);
			cmd.SetGlobalTexture("_Shadowmap", shadowmap);

			InitShadowmapDummy();
			proxyMaterial.SetTexture("_ShadowmapDummy", shadowmapDummy);

			cmd.SetGlobalMatrix("_ShadowProjectionMatrix", GetProjectionMatrix());

			float texelsInMap = (int) shadowmapRes;

			cmd.SetGlobalFloat("_ShadowReceiverWidth", receiverSearchDistance / c_maxDistance);
			cmd.SetGlobalFloat("_ShadowReceiverDistanceScale",
				receiverDistanceScale * 0.5f / 10.0f); //在shader中的10次采样的单次距离 左右*0.5

			//[near,far]=>[0,1]
			cmd.SetGlobalVector("_ShadowLightWidth", new Vector2(lightNearSize, lightFarSize) / c_maxDistance);

			cmd.SetGlobalFloat("_ShadowBias", shadowBias);
		}

		private void UpdateShadowmap(int res)
		{
			if (shadowmap != null && shadowmapRenderTime == Time.renderedFrameCount)
			{
				return;
			}

			if (!CreateCamera())
			{
				return;
			}

			UpdateShadowmapCamera();

			CreateShadowmap(res);

			// TODO:清空RT. RenderWithShader() 也应该被clear, 但是它没有  应该属于BUG.
			shadowmapCamera.cullingMask = 0;
			shadowmapCamera.Render();
			shadowmapCamera.cullingMask = shadowCullingMask;

			//我们可能在PlaneReflections内部渲染，这会反转剔除。暂时禁用。
			var oldCulling = GL.invertCulling;
			GL.invertCulling = false;

			//把 根shadowmapShader的"RenderType"相同的shader 替换成  shadowmapShader
			shadowmapCamera.RenderWithShader(shadowmapShader, "RenderType");

			GL.invertCulling = oldCulling;
			shadowmapRenderTime = Time.renderedFrameCount;
		}

		private bool CreateCamera()
		{
			//Create the Camera
			if (shadowmapCamera == null)
			{
				if (shadowmapShader == null)
				{
					Debug.LogError("AreaLight's shadowmap shader not assigned.", this);
					return false;
				}

				GameObject go = new GameObject("Shadowmap Camera");
				shadowmapCamera = go.AddComponent<Camera>();
				go.hideFlags = HideFlags.HideAndDontSave;
				shadowmapCamera.enabled = false;
				shadowmapCamera.clearFlags = CameraClearFlags.SolidColor;
				shadowmapCamera.renderingPath = RenderingPath.Forward;
				// exp(EXPONENT) for ESM, white for VSM
				// m_ShadowmapCamera.backgroundColor = new Color(Mathf.Exp(EXPONENT), 0, 0, 0);
				shadowmapCamera.backgroundColor = Color.white;
				shadowmapCameraTransform = go.transform;
				shadowmapCameraTransform.parent = transform;
				shadowmapCameraTransform.localRotation = Quaternion.identity;
			}

			return true;
		}

		private void UpdateShadowmapCamera()
		{
			if (angle == 0.0f)
			{
				//角度是0  则是orthographic
				shadowmapCamera.orthographic = true;
				shadowmapCameraTransform.localPosition = Vector3.zero;
				shadowmapCamera.nearClipPlane = 0;
				shadowmapCamera.farClipPlane = size.z;
				shadowmapCamera.orthographicSize = 0.5f * size.y;
				shadowmapCamera.aspect = size.x / size.y;
			}
			else
			{
				shadowmapCamera.orthographic = false;
				float near = GetNearToCenter();
				//local vector3.forward  ==  world trasnform.forward
				shadowmapCameraTransform.localPosition = -near * Vector3.forward;
				shadowmapCamera.nearClipPlane = near;
				shadowmapCamera.farClipPlane = near + size.z;
				shadowmapCamera.fieldOfView = angle;
				shadowmapCamera.aspect = size.x / size.y;
			}
		}

		private void CreateShadowmap(int res)
		{
			if (shadowmap != null && shadowmap.width == res)
			{
				return;
			}

			ReleaseTemporary(ref shadowmap);
			shadowmap = RenderTexture.GetTemporary(res, res, 24, RenderTextureFormat.Shadowmap);
			shadowmap.name = "AreaLight Shadowmap";
			shadowmap.filterMode = FilterMode.Bilinear;
			shadowmap.wrapMode = TextureWrapMode.Clamp;

			shadowmapCamera.targetTexture = shadowmap;
		}

		private void InitShadowmapDummy()
		{
			if (shadowmapDummy != null)
			{
				return;
			}

			shadowmapDummy = new Texture2D(1, 1, TextureFormat.Alpha8, false, true);
			shadowmapDummy.filterMode = FilterMode.Point;
			shadowmapDummy.SetPixel(0, 0, new Color(0, 0, 0, 0));
			shadowmapDummy.Apply(false, true);
		}


		//camera target is shadowmap?
		private bool InsideShadowmapCameraRender()
		{
			RenderTexture target = Camera.current == null ? null : Camera.current.targetTexture;
			return target != null && target.format == RenderTextureFormat.Shadowmap;
		}
	}
}