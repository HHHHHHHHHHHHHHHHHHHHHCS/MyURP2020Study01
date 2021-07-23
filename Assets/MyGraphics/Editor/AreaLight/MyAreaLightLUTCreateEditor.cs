using System.IO;
using MyGraphics.Scripts.AreaLight;
using UnityEditor;
using UnityEngine;
using static MyGraphics.Scripts.AreaLight.MyAreaLightLUT;


namespace MyGraphics.Editor.AreaLight
{
	public static class MyAreaLightLUTCreateEditor
	{
		[MenuItem("Tools/AreaLight/LutAsset")]
		public static void CreateLut()
		{
			MyAreaLightLUT lut = ScriptableObject.CreateInstance<MyAreaLightLUT>();
			AssetDatabase.CreateAsset(lut, "Assets/LUTAsset.asset");
		}

		[MenuItem("Tools/AreaLight/AllTexture")]
		public static void CreateAllTexture()
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
			var filePath = name + ".exr";

			var texture =
				MyAreaLightLUTTools.LoadLut(type);

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
			defaultSettings.format = TextureImporterFormat.Automatic;
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