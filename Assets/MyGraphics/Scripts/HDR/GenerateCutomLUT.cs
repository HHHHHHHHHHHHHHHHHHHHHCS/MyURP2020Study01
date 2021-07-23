using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.HDR
{
	public class GenerateCutomLUT : MonoBehaviour
	{
#if UNITY_EDITOR
		public ComputeShader generateShader;
		public Texture2D inputLUT;
		public string outputName = "custom_lut";
#endif
	}
}