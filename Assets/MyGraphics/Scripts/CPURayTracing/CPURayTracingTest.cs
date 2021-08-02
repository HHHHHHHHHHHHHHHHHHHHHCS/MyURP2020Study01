using System;
using System.Diagnostics;
using Unity.Collections;
using UnityEngine;
using UnityEngine.UI;
using Debug = UnityEngine.Debug;

namespace MyGraphics.Scripts.CPURayTracing
{
	public class CPURayTracingTest : MonoBehaviour
	{
		public int screenWidth, screenHeight;

		public Text uiPrefText;
		public RawImage uiImage;

		private Texture2D backBufferTex;
		private NativeArray<Color> backBuffer;
		private CPURayTracing rayTracing;

		private Stopwatch stopWatch;
		private int updateCounter;
		private int frameCounter;
		private long rayCounter;


		private void Start()
		{
			int width = screenWidth; //Screen.width;
			int height = screenHeight; // Screen.height;

			backBufferTex = new Texture2D(width, height, TextureFormat.RGBAFloat, false, true);
			backBuffer = new NativeArray<Color>(width * height, Allocator.Persistent);
			for (int i = 0; i < backBuffer.Length; i++)
			{
				backBuffer[i] = new Color(0, 0, 0, 1);
			}

			uiImage.texture = backBufferTex;

			rayTracing = new CPURayTracing();
			stopWatch = new Stopwatch();
		}

		private void OnDestroy()
		{
			backBuffer.Dispose();
			rayTracing.Dispose();
		}
		
		private void Update()
		{
			UpdateLoop();
			// if (updateCounter == 10)
			// {
			// 	var s = (float) ((double) stopWatch.ElapsedTicks / Stopwatch.Frequency) / updateCounter;
			// 	var ms = s * 1000.0f;
			// 	//1.0e-6f 百万
			// 	var mrayS = (float) rayCounter / updateCounter / s * 1.0e-6f;
			// 	var mrayFr = (float) rayCounter / updateCounter * 1.0e-6f;
			// 	uiPrefText.text =
			// 		$"{ms:F2}ms ({1.0f / s:F2}FPS) {mrayS:F2}Mrays/s {mrayFr:F2}Mrays/frame {frameCounter} frames";
			// 	updateCounter = 0;
			// 	rayCounter = 0;
			// 	stopWatch.Reset();
			// }

			backBufferTex.LoadRawTextureData(backBuffer);
			backBufferTex.Apply();
		}
		
		private void UpdateLoop()
		{
			// stopWatch.Start();
			int rayCount;
			rayTracing.DoDraw(Time.timeSinceLevelLoad, frameCounter++, backBufferTex.width, backBufferTex.height,
				backBuffer, out rayCount);
			// stopWatch.Stop();
			// updateCounter++;
			// rayCounter += rayCount;
		}
	}
}