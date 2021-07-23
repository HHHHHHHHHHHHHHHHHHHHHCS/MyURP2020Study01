using MyGraphics.Scripts.AreaLight;
using UnityEngine;
using static MyGraphics.Scripts.AreaLight.MyAreaLightLUT;

namespace MyGraphics.Editor.AreaLight
{
	public partial class MyAreaLightLUTTools
	{
		[ColorUsage(false)]
		private Color c;
		private const int kLUTResolution = 64;
		private const int kLUTMatrixDim = 3;

		public static Texture2D LoadLut(MyAreaLightLUT.LUTType type)
		{
			switch (type)
			{
				case MyAreaLightLUT.LUTType.TransformInv_DisneyDiffuse: return LoadLUT(s_LUTTransformInv_DisneyDiffuse);
				case MyAreaLightLUT.LUTType.TransformInv_GGX: return LoadLUT(s_LUTTransformInv_GGX);
				case MyAreaLightLUT.LUTType.AmpDiffAmpSpecFresnel:
					return LoadLUT(s_LUTAmplitude_DisneyDiffuse, s_LUTAmplitude_GGX, s_LUTFresnel_GGX);
			}

			return null;
		}

		private static Texture2D CreateLUT(TextureFormat format, Color[] pixels)
		{
			Texture2D tex = new Texture2D(kLUTResolution, kLUTResolution, format, false, true)
			{
				hideFlags = HideFlags.HideAndDontSave, 
				wrapMode = TextureWrapMode.Clamp
			};
			tex.SetPixels(pixels);
			tex.Apply();
			return tex;
		}

		private static Texture2D LoadLUT(double[,] LUTTrasnformInv)
		{
			const int count = kLUTResolution * kLUTResolution;
			Color[] pixels = new Color[count];

			for (int i = 0; i < count; i++)
			{
				// 只有 0，2，4，6   GGX
				pixels[i] = new Color(
					(float) LUTTrasnformInv[i, 0],
					(float) LUTTrasnformInv[i, 2],
					(float) LUTTrasnformInv[i, 4],
					(float) LUTTrasnformInv[i, 6]
				);
			}

			return CreateLUT(TextureFormat.RGBAHalf, pixels);
		}

		private static Texture2D LoadLUT(float[] LUTScalar0, float[] LUTScalar1, float[] LUTScalar2)
		{
			const int count = kLUTResolution * kLUTResolution;
			Color[] pixels = new Color[count];

			for (int i = 0; i < count; i++)
			{
				pixels[i] = new Color(LUTScalar0[i], LUTScalar1[i], LUTScalar2[i], 1);
			}

			return CreateLUT(TextureFormat.RGBAHalf, pixels);
		}
	}
}