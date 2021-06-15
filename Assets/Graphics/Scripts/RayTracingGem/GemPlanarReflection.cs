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

		public GameObject target;

		private Camera mainCamera;

		private Camera reflectionCamera;
		private RenderTexture reflectionTexture;


		private void OnEnable()
		{
			mainCamera = Camera.main;
			CreateReflectionCamera();
			CreateReflectionRT();
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
				RenderTexture.ReleaseTemporary(reflectionTexture);
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

			if (Camera.main != camera)
			{
				return;
			}

			var oldCulling = GL.invertCulling;
			var oldFog = RenderSettings.fog;
			var oldMax = QualitySettings.maximumLODLevel;
			var oldBias = QualitySettings.lodBias;

			//剔除时针改变  显示背面  因为水可能要背面
			GL.invertCulling = false;
			RenderSettings.fog = false;
			QualitySettings.maximumLODLevel = 1;
			QualitySettings.lodBias = oldBias * 0.5f;

			// UpdateReflectionCamera();

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
			var camGO = new GameObject(k_cameraName)
			{
				hideFlags = HideFlags.HideAndDontSave
			};

			var newCameraData =
				camGO.AddComponent<UniversalAdditionalCameraData>();
			// var currentCameraData =
			// 	currentCamera.GetComponent<UniversalAdditionalCameraData>();
			newCameraData.renderShadows = true;
			newCameraData.requiresColorOption = CameraOverrideOption.Off;
			newCameraData.requiresDepthOption = CameraOverrideOption.Off;

			reflectionCamera = camGO.AddComponent<Camera>();
			reflectionCamera.transform.SetPositionAndRotation(
				mainCamera.transform.position, mainCamera.transform.rotation);
			reflectionCamera.allowMSAA = mainCamera.allowMSAA;
			reflectionCamera.depth = mainCamera.depth - 10; //保证优先渲染
			reflectionCamera.allowHDR = mainCamera.allowHDR;

			reflectionCamera.enabled = false;
		}

		private void CreateReflectionRT()
		{
			reflectionTexture = new RenderTexture(mainCamera.scaledPixelWidth, mainCamera.pixelHeight, 24);
			reflectionCamera.targetTexture = reflectionTexture;
		}
	}
}