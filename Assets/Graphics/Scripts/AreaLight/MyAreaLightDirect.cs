using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.AreaLight
{
	public partial class MyAreaLight : MonoBehaviour
	{
		private const CameraEvent c_cameraEvent = CameraEvent.AfterLighting;

		private static readonly float[,] s_offsets = new float[4, 2] {{1, 1}, {1, -1}, {-1, -1}, {-1, 1}};

		private static Texture2D s_TransformInvTexture_Specular;
		private static Texture2D s_TransformInvTexture_Diffuse;
		private static Texture2D s_AmpDiffAmpSpecFresnel;

		private readonly Dictionary<Camera, CommandBuffer> cameras = new Dictionary<Camera, CommandBuffer>();


		public Shader proxyShader;

		public Mesh cubeMesh;

		private Material proxyMaterial;

		private bool InitDirect()
		{
			if (proxyShader == null || cubeMesh == null)
			{
				return false;
			}

			proxyMaterial = new Material(proxyShader);
			proxyMaterial.hideFlags = HideFlags.HideAndDontSave;

			return true;
		}

		private void SetupLUTs()
		{
			if (s_TransformInvTexture_Diffuse == null)
			{
				s_TransformInvTexture_Diffuse =
					MyAreaLightLUT.LoadLut(MyAreaLightLUT.LUTType.TransformInv_DisneyDiffuse);
			}

			if (s_TransformInvTexture_Specular == null)
			{
				s_TransformInvTexture_Specular = MyAreaLightLUT.LoadLut(MyAreaLightLUT.LUTType.TransformInv_GGX);
			}

			if (s_AmpDiffAmpSpecFresnel == null)
			{
				s_AmpDiffAmpSpecFresnel = MyAreaLightLUT.LoadLut(MyAreaLightLUT.LUTType.AmpDiffAmpSpecFresnel);
			}

			proxyMaterial.SetTexture("_TransformInv_Diffuse", s_TransformInvTexture_Diffuse);
			proxyMaterial.SetTexture("_TransformInv_Specular", s_TransformInvTexture_Specular);
			proxyMaterial.SetTexture("_AmpDiffAmpSpecFresnel", s_AmpDiffAmpSpecFresnel);
		}

		private void SetupCommandBuffer()
		{
			//camera target is shadowmap
			if (InsideShadowmapCameraRender())
			{
				return;
			}

			var cam = Camera.current;
			var buf = GetOrCreateCommandBuffer(cam);

			buf.SetGlobalVector("_LightPos", transform.position);
			buf.SetGlobalVector("_LightColor", GetColor());
			SetupLUTs();

			//vert_deferred vertex shader 需要 UnityDeferredLibrary.cginc
			//TODO:如果灯光与近平面和远平面相交，则将其渲染为四边形。
			//（还缺少：当靠近不相交时作为前面板渲染，模板优化）
			buf.SetGlobalFloat("_LightAsQuad", 0);

			//向前偏移一点，以防止光照到自己-四边片
			var z = 0.01f;
			var t = transform;

			var lightVerts = new Matrix4x4();
			for (var i = 0; i < 4; i++)
			{
				lightVerts.SetRow(i
					, t.TransformPoint(new Vector3(size.x * s_offsets[i, 0], size.y * s_offsets[i, 1], z) * 0.5f));
			}
			buf.SetGlobalMatrix("_LightVerts",lightVerts);

			if (enableShadows)
			{
				
			}
			
		}

		private void Cleanup()
		{
			using var e = cameras.GetEnumerator();
			for (; e.MoveNext();)
			{
				var cam = e.Current;
				if (cam.Key != null && cam.Value != null)
				{
					cam.Key.RemoveCommandBuffer(c_cameraEvent, cam.Value);
				}
			}

			cameras.Clear();
		}

		private CommandBuffer GetOrCreateCommandBuffer(Camera cam)
		{
			if (cam == null)
			{
				return null;
			}

			CommandBuffer buffer = null;
			if (!cameras.ContainsKey(cam))
			{
				buffer = new CommandBuffer();
				buffer.name = /*"Area Light: "+*/gameObject.name;
				cameras[cam] = buffer;
				cam.AddCommandBuffer(c_cameraEvent, buffer);
				cam.depthTextureMode |= DepthTextureMode.Depth;
			}
			else
			{
				buffer = cameras[cam];
				buffer.Clear();
			}

			return buffer;
		}

		private void ReleaseTemporary(ref RenderTexture rt)
		{
			if (rt == null)
			{
				return;
			}
			
			RenderTexture.ReleaseTemporary(rt);
			rt = null;
		}
		
		private Color GetColor()
		{
			if (QualitySettings.activeColorSpace == ColorSpace.Gamma)
			{
				return lightColor * intensity;
			}

			return new Color(
				Mathf.GammaToLinearSpace(lightColor.r),
				Mathf.GammaToLinearSpace(lightColor.g),
				Mathf.GammaToLinearSpace(lightColor.b),
				1.0f
			);
		}
	}
}