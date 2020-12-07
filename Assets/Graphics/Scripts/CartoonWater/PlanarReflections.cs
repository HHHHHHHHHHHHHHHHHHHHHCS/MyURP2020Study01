using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.CartoonWater
{
	//TODO:
	//1.其实可以用上一帧的图 做翻转  这样不会重新再次渲染一遍
	//2.添加一个pass 设置VP 只画简单的opaque和transparent
	//但是这里  只是做尝试
	[ExecuteAlways, RequireComponent(typeof(Camera))]
	public class PlanarReflections : MonoBehaviour
	{
		[System.Serializable]
		public enum ResolutionMultiplier
		{
			Full,
			Half,
			Third,
			Quarter,
		}

		[System.Serializable]
		public class PlanarReflectionSettings
		{
			public ResolutionMultiplier resolutionMultiplier = ResolutionMultiplier.Third;
			public float clipPlaneOffset = 0.07f;
			public LayerMask reflectLayers = -1;
			public bool shadows;
		}

		public static Camera reflectionCamera;

		private readonly int planarReflectionTexture_PTID = Shader.PropertyToID("_PlanarReflectionTexture");


		[SerializeField] public PlanarReflectionSettings settings = new PlanarReflectionSettings();
		public GameObject target; //水面板
		public float planeOffset;

		private RenderTexture reflectionTexture = null;
		private Vector2Int oldReflectionTextureSize;

		private void OnEnable()
		{
			RenderPipelineManager.beginCameraRendering += ExecuteBeforeCameraRender;
		}

		private void OnDisable()
		{
			Cleanup();
		}

		private void Cleanup()
		{
			RenderPipelineManager.beginCameraRendering -= ExecuteBeforeCameraRender;

			if (reflectionCamera)
			{
				reflectionCamera.targetTexture = null;
				SafeDestroy(reflectionCamera.gameObject);
			}

			if (reflectionTexture)
			{
				RenderTexture.ReleaseTemporary(reflectionTexture);
				reflectionTexture = null;
			}
		}

		private void SafeDestroy(UnityEngine.Object obj)
		{
			if (Application.isEditor)
			{
				DestroyImmediate(obj);
			}
			else
			{
				Destroy(obj);
			}
		}

		private void ExecuteBeforeCameraRender(ScriptableRenderContext context, Camera camera)
		{
			if (!enabled)
			{
				return;
			}

			var oldCulling = GL.invertCulling;
			var oldFog = RenderSettings.fog;
			var oldMax = QualitySettings.maximumLODLevel;
			var oldBias = QualitySettings.lodBias;
			//剔除时针改变  显示背面  因为水可能要背面
			GL.invertCulling = true;
			RenderSettings.fog = oldFog;
			QualitySettings.maximumLODLevel = 1;
			QualitySettings.lodBias = oldBias * 0.5f;

			UpdateReflectionCamera(camera);

			var res = ReflectionResolution(camera, UniversalRenderPipeline.asset.renderScale);
			if (reflectionTexture == null)
			{
				bool useHDR10 = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RGB111110Float);
				RenderTextureFormat hdrFormat = useHDR10
					? RenderTextureFormat.RGB111110Float
					: RenderTextureFormat.Default;
				reflectionTexture = RenderTexture.GetTemporary(res.x, res.y, 16
					, GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
				reflectionTexture.useMipMap = true;
				reflectionTexture.autoGenerateMips = true;
			}

			reflectionCamera.targetTexture = reflectionTexture;

			UniversalRenderPipeline.RenderSingleCamera(context, reflectionCamera);

			GL.invertCulling = oldCulling;
			RenderSettings.fog = oldFog;
			QualitySettings.maximumLODLevel = oldMax;
			QualitySettings.lodBias = oldBias;
			Shader.SetGlobalTexture(planarReflectionTexture_PTID, reflectionTexture);
		}

		private void UpdateReflectionCamera(Camera realCamera)
		{
			if (reflectionCamera == null)
			{
				reflectionCamera = CreateMirrorObjects(realCamera);
			}

			Vector3 pos = Vector3.zero;
			Vector3 normal = Vector3.up;
			if (target != null)
			{
				pos = target.transform.position + Vector3.up * planeOffset;
				normal = target.transform.up;
			}

			UpdateCameraProperties(realCamera, reflectionCamera);

			float d = -Vector3.Dot(normal, pos) - settings.clipPlaneOffset; //摄像机旋转相对的高度偏移
			Vector4 reflectionPlane = new Vector4(normal.x, normal.y, normal.z, d); //平面方程式
			Matrix4x4 reflection = CalculateReflectionMatrix(reflectionPlane); //平面矩阵

			// Vector3 oldPos = realCamera.transform.position - new Vector3(0, pos.y * 2, 0);
			// Vector3 newPos = ReflectionPosition(oldPos);
			Vector3 newPos = realCamera.transform.position;
			//摄像机朝向翻转
			reflectionCamera.transform.forward = Vector3.Scale(realCamera.transform.forward, new Vector3(1, -1, 1));
			//矩阵转换到 反射矩阵下
			reflectionCamera.worldToCameraMatrix = reflectionCamera.worldToCameraMatrix * reflection;

			//斜投影矩阵
			//https://acgmart.com/render/planar-reflection-based-on-distance/
			//https://www.cnblogs.com/wantnon/p/4569096.html
			Vector4 clipPlane = CameraSpacePlane(reflectionCamera, pos - Vector3.up * 0.1f, normal, 1.0f);
			Matrix4x4 projection = realCamera.CalculateObliqueMatrix(clipPlane);
			reflectionCamera.projectionMatrix = projection;
			reflectionCamera.cullingMask = settings.reflectLayers; //不渲染水 layer
			reflectionCamera.transform.position = newPos; //其实意义不大
		}

		private Camera CreateMirrorObjects(Camera currentCamera)
		{
			//SRP 应该可以直接set vp 的
			//不用创建新的摄像机
			GameObject go =
				new GameObject(
					$"Planar Refl Camera id{GetInstanceID().ToString()} for {currentCamera.GetInstanceID().ToString()}",
					typeof(Camera));
			var newCameraData =
				go.AddComponent<UniversalAdditionalCameraData>();
			// var currentCameraData =
			// 	currentCamera.GetComponent<UniversalAdditionalCameraData>();
			newCameraData.renderShadows = settings.shadows;
			newCameraData.requiresColorOption = CameraOverrideOption.Off;
			newCameraData.requiresDepthOption = CameraOverrideOption.Off;

			var refCam = go.GetComponent<Camera>();
			refCam.transform.SetPositionAndRotation(transform.position, transform.rotation);
			refCam.allowMSAA = currentCamera.allowMSAA;
			refCam.depth = currentCamera.depth - 10; //保证优先渲染
			refCam.allowHDR = currentCamera.allowHDR;
			go.hideFlags = HideFlags.HideAndDontSave;

			return refCam;
		}

		private void UpdateCameraProperties(Camera src, Camera dest)
		{
			if (dest == null)
			{
				return;
			}

			dest.CopyFrom(src); //复制camera设置
			dest.cameraType = src.cameraType;
			dest.useOcclusionCulling = false;
		}

		//将这个摄像机的worldToCameraMatrix乘以反射矩阵reflectionMatrix
		//https://gameinstitute.qq.com/community/detail/106151
		//https://zhuanlan.zhihu.com/p/74529106
		private Matrix4x4 CalculateReflectionMatrix(Vector4 plane)
		{
			Matrix4x4 reflectionMatrix;

			reflectionMatrix.m00 = (1f - 2f * plane[0] * plane[0]);
			reflectionMatrix.m01 = (-2f * plane[0] * plane[1]);
			reflectionMatrix.m02 = (-2f * plane[0] * plane[2]);
			reflectionMatrix.m03 = (-2f * plane[3] * plane[0]);

			reflectionMatrix.m10 = (-2f * plane[1] * plane[0]);
			reflectionMatrix.m11 = (1f - 2f * plane[1] * plane[1]);
			reflectionMatrix.m12 = (-2f * plane[1] * plane[2]);
			reflectionMatrix.m13 = (-2f * plane[3] * plane[1]);

			reflectionMatrix.m20 = (-2f * plane[2] * plane[0]);
			reflectionMatrix.m21 = (-2f * plane[2] * plane[1]);
			reflectionMatrix.m22 = (1f - 2f * plane[2] * plane[2]);
			reflectionMatrix.m23 = (-2f * plane[3] * plane[2]);

			reflectionMatrix.m30 = 0f;
			reflectionMatrix.m31 = 0f;
			reflectionMatrix.m32 = 0f;
			reflectionMatrix.m33 = 1f;

			return reflectionMatrix;
		}

		private Vector3 ReflectionPosition(Vector3 pos)
		{
			Vector3 newPos = new Vector3(pos.x, -pos.y, pos.z);
			return newPos;
		}

		private Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
		{
			Vector3 offsetPos = pos + normal * settings.clipPlaneOffset;
			Matrix4x4 m = cam.worldToCameraMatrix;
			Vector3 cpos = m.MultiplyPoint(offsetPos);
			Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign; //direction
			return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
		}

		private float GetScaleValue()
		{
			switch (settings.resolutionMultiplier)
			{
				case ResolutionMultiplier.Full:
					return 1f;
				case ResolutionMultiplier.Half:
					return 0.5f;
				case ResolutionMultiplier.Third:
					return 0.33f;
				case ResolutionMultiplier.Quarter:
					return 0.25f;
			}

			return 0.5f;
		}

		private Vector2Int ReflectionResolution(Camera cam, float scale)
		{
			var x = (int) (cam.pixelWidth * scale * GetScaleValue());
			var y = (int) (cam.pixelHeight * scale * GetScaleValue());
			return new Vector2Int(x, y);
		}
	}
}