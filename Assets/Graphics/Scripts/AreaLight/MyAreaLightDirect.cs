using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.AreaLight
{
	public partial class MyAreaLight : MonoBehaviour
	{
		private const CameraEvent c_cameraEvent = CameraEvent.AfterLighting;

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
	}
}