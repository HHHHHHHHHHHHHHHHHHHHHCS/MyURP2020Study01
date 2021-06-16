using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace Graphics.Scripts.RayTracingGem
{
	public class GemPlanarReflection : MonoBehaviour
	{
		private const string k_cameraName = "Planar Reflection Camera";

		private static readonly int ReflectionTex_ID = Shader.PropertyToID("_ReflectionTex");

		public Transform reflectPlane;

		private Camera mainCamera;
		private Transform mainCameraTS;

		private Camera reflectionCamera;
		private RenderTexture reflectionTexture;


		private void OnEnable()
		{
			mainCamera = Camera.main;
			mainCameraTS = mainCamera.transform;
			RenderPipelineManager.beginCameraRendering += ExecuteBeforeCameraRender;
		}

		private void OnDisable()
		{
			RenderPipelineManager.beginCameraRendering -= ExecuteBeforeCameraRender;

			if (reflectionCamera)
			{
				reflectionCamera.targetTexture = null;
				SafeDestroy(reflectionCamera.gameObject);
				reflectionCamera = null;
			}

			if (reflectionTexture)
			{
				SafeDestroy(reflectionTexture);
				reflectionTexture = null;
			}
		}

		private void SafeDestroy(Object obj)
		{
			if (obj == null)
			{
				return;
			}

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

			if (reflectPlane == null)
			{
				return;
			}

			if (Camera.main != camera)
			{
				return;
			}

			CreateReflectionCamera();
			CreateReflectionRT();

			var oldCulling = GL.invertCulling;
			var oldFog = RenderSettings.fog;
			var oldMax = QualitySettings.maximumLODLevel;
			var oldBias = QualitySettings.lodBias;

			//确保剔除顺序是正确的
			GL.invertCulling = false;
			RenderSettings.fog = false;
			QualitySettings.maximumLODLevel = 1;
			QualitySettings.lodBias = oldBias * 0.5f;

			UpdateReflectionCamera();

			UniversalRenderPipeline.RenderSingleCamera(context, reflectionCamera);

			GL.invertCulling = oldCulling;
			RenderSettings.fog = oldFog;
			QualitySettings.maximumLODLevel = oldMax;
			QualitySettings.lodBias = oldBias;
			Shader.SetGlobalTexture(ReflectionTex_ID, reflectionTexture);
		}


		//SRP 应该可以直接set vp 的
		//不用创建新的摄像机
		private void CreateReflectionCamera()
		{
			if (reflectionCamera != null)
			{
				return;
			}

			var camGO = new GameObject(k_cameraName)
			{
				hideFlags = HideFlags.HideAndDontSave
			};

			//添加了 UniversalAdditionalCameraData  会自动添加Camera
			reflectionCamera = camGO.AddComponent<Camera>();
			reflectionCamera.transform.SetPositionAndRotation(
				mainCameraTS.position, mainCameraTS.rotation);
			reflectionCamera.allowMSAA = mainCamera.allowMSAA;
			reflectionCamera.depth = mainCamera.depth - 10; //保证优先渲染
			reflectionCamera.allowHDR = mainCamera.allowHDR;
			reflectionCamera.enabled = false;

			var newCameraData =
				camGO.AddComponent<UniversalAdditionalCameraData>();
			// var currentCameraData =
			// 	currentCamera.GetComponent<UniversalAdditionalCameraData>();
			newCameraData.renderShadows = true;
			newCameraData.requiresColorOption = CameraOverrideOption.Off;
			newCameraData.requiresDepthOption = CameraOverrideOption.Off;
		}

		private void CreateReflectionRT()
		{
			if (reflectionTexture != null)
			{
				return;
			}

			reflectionTexture = new RenderTexture(mainCamera.scaledPixelWidth, mainCamera.pixelHeight, 24);
			reflectionCamera.targetTexture = reflectionTexture;
		}

		private void UpdateReflectionCamera()
		{
			reflectionCamera.CopyFrom(mainCamera);

			Vector3 camForward = mainCameraTS.forward;
			Vector3 camUp = mainCameraTS.up;
			Vector3 camPos = mainCameraTS.position;

			//把世界坐标转换到 local 坐标
			//Direction 还不受缩放影响   Point受到缩放影响
			Vector3 camForwardPlaneSpace = reflectPlane.InverseTransformDirection(camForward);
			Vector3 camUpPlaneSpace = reflectPlane.InverseTransformDirection(camUp);
			Vector3 camPosPlaneSpace = reflectPlane.InverseTransformPoint(camPos);

			//Mirror the vectors
			camForwardPlaneSpace.y *= -1.0f;
			camUpPlaneSpace.y *= -1.0f;
			camPosPlaneSpace.y *= -1.0f;

			camForward = reflectPlane.TransformDirection(camForwardPlaneSpace);
			camUp = reflectPlane.TransformDirection(camUpPlaneSpace);
			camPos = reflectPlane.TransformPoint(camPosPlaneSpace);

			reflectionCamera.transform.position = camPos;
			reflectionCamera.transform.LookAt(camPos + camForward, camUp);
		}
	}
}