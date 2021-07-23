using UnityEditor;
using UnityEngine;
using System.IO;
using MyGraphics.Scripts.HDR;
using UnityEngine.Rendering;

namespace MyGraphics.Editor.HDR
{
	[CustomEditor(typeof(GenerateCutomLUT))]
	public class GenerateCutomLUTEditor : UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			DrawDefaultInspector();

			GenerateCutomLUT script = target as GenerateCutomLUT;
			if (GUILayout.Button("Generate"))
			{
				Generate(script);
				AssetDatabase.Refresh();
			}
		}

		public void Generate(GenerateCutomLUT target)
		{
			ComputeShader generateShader = target.generateShader;
			Texture2D inputLUT = target.inputLUT;
			string outputName = target.outputName;

			if (!inputLUT || !generateShader)
			{
				return;
			}

			var stack = VolumeManager.instance.stack;
			if (stack == null)
			{
				return;
			}

			var tonemapSettings = stack.GetComponent<CustomTonemapSettings>();
			if (!tonemapSettings || !tonemapSettings.enable.value)
			{
				return;
			}

			float exposure = tonemapSettings.exposure.value;
			float saturation = tonemapSettings.saturation.value;
			float contrast = tonemapSettings.contrast.value;

			int width = inputLUT.width;
			int height = inputLUT.height;
			RenderTexture colorLut = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBFloat,
				RenderTextureReadWrite.Linear);
			colorLut.enableRandomWrite = true; //给compute shader RWTexture 用
			colorLut.Create(); //apply

			int kernel = generateShader.FindKernel("CSMain");

			generateShader.SetFloat("_Exposure", exposure);
			generateShader.SetFloat("_Saturation", saturation);
			generateShader.SetFloat("_Contrast", contrast);
			generateShader.SetTexture(kernel, "_InputTex", inputLUT);
			generateShader.SetTexture(kernel, "_OutputTex", colorLut);

			generateShader.Dispatch(kernel, width / 8, height / 8, 1);

			//save lut to exr file
			Texture2D outputTex = new Texture2D(width, height, TextureFormat.RGBAFloat, false);

			RenderTexture currentActive = RenderTexture.active;
			RenderTexture.active = colorLut;
			outputTex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
			outputTex.Apply();
			RenderTexture.active = currentActive;

			byte[] bytes = outputTex.EncodeToEXR(Texture2D.EXRFlags.CompressZIP);
			string outputPath = Application.dataPath + "/" + outputName + ".exr";
			File.WriteAllBytes(outputPath, bytes);
			Debug.Log("Saved Color Lut to " + outputPath);

			colorLut.Release();
			DestroyImmediate(colorLut);
			DestroyImmediate(outputTex);
		}
	}
}