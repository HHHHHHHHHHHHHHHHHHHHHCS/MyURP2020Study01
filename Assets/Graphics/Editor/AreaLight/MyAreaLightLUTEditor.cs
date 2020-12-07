using System.IO;
using Graphics.Scripts.AreaLight;
using UnityEditor;
using UnityEngine;

namespace Graphics.Editor.AreaLight
{
	public static class MyAreaLightLUTEditor
	{
		[MenuItem("Tools/AreaLight/All")]
		public static void CreateAll()
		{
			CreateDisneyDiffuse();
			CreateGGX();
			CreateAmpDiffAmpSpecFresnel();
		}

		[MenuItem("Tools/AreaLight/DisneyDiffuse")]
		public static void CreateDisneyDiffuse()
		{
			CreateAndSave("DisneyDiffuse", MyAreaLightLUT.LUTType.TransformInv_DisneyDiffuse);
		}

		[MenuItem("Tools/AreaLight/GGX")]
		public static void CreateGGX()
		{
			CreateAndSave("GGX", MyAreaLightLUT.LUTType.TransformInv_GGX);
		}

		[MenuItem("Tools/AreaLight/AmpDiffAmpSpecFresnel")]
		public static void CreateAmpDiffAmpSpecFresnel()
		{
			CreateAndSave("AreaLightAmpDiffAmpSpecFresnel", MyAreaLightLUT.LUTType.AmpDiffAmpSpecFresnel);
		}

		private static void CreateAndSave(string name, MyAreaLightLUT.LUTType type)
		{
			var filePath =   name + ".exr";

			var texture =
				MyAreaLightLUT.LoadLut(type);

			//using auto close
			using var fs = new FileStream(Application.dataPath + "/" + filePath, FileMode.Create);
			using var binary = new BinaryWriter(fs);
			binary.Write(texture.EncodeToEXR());

			AssetDatabase.Refresh();

			var ti = AssetImporter.GetAtPath("Assets/" + filePath) as TextureImporter;
			ti.sRGBTexture = false;
			ti.mipmapEnabled = false;
			ti.wrapMode = TextureWrapMode.Clamp;

			var defaultSettings = ti.GetDefaultPlatformTextureSettings();
			defaultSettings.format = TextureImporterFormat.RGBA32;
			defaultSettings.textureCompression = TextureImporterCompression.Uncompressed;
			ti.SetPlatformTextureSettings(defaultSettings);

			var PCSettings = ti.GetPlatformTextureSettings("Standalone");
			PCSettings.overridden = true;
			PCSettings.format = TextureImporterFormat.RGBAHalf;
			ti.SetPlatformTextureSettings(PCSettings);

			ti.SaveAndReimport();
		}
	}
}