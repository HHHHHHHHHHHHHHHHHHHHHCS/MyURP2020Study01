using System;
using UnityEngine;
using Object = UnityEngine.Object;

namespace MyGraphics.Scripts.Skinner
{
	internal class AnimationKernelSet<KernelEnum, BufferEnum>
		where KernelEnum : struct
		where BufferEnum : struct
	{
		public delegate int KernelEnumToInt(KernelEnum e);

		public delegate int BufferEnumToInt(BufferEnum e);

		private KernelEnumToInt getKernelIndex;
		private BufferEnumToInt getBufferIndex;

		private Shader shader;
		private Material material;

		private RenderTexture[] renderTextures;
		private bool swapFlag;
		private bool ready;

		public Material Material => material;

		public bool Ready => ready;

		public AnimationKernelSet(Shader _shader, KernelEnumToInt k2i, BufferEnumToInt b2i)
		{
			shader = _shader;
			getKernelIndex = k2i;
			getBufferIndex = b2i;

			var enumCount = Enum.GetValues(typeof(BufferEnum)).Length;
			renderTextures = new RenderTexture[enumCount * 2];
		}

		public void Setup(int width, int height)
		{
			if (ready)
			{
				return;
			}

			material = new Material(shader);

			var format = RenderTextureFormat.ARGBFloat;

			for (var i = 0; i < renderTextures.Length; i++)
			{
				var rt = new RenderTexture(width, height, 0, format)
				{
					filterMode = FilterMode.Point,
					wrapMode = TextureWrapMode.Clamp
				};
				renderTextures[i] = rt;
			}

			swapFlag = false;
			ready = true;
		}

		public void Release()
		{
			if (!ready)
			{
				return;
			}

			Object.Destroy(material);
			material = null;


			for (int i = 0; i < renderTextures.Length; i++)
			{
				Object.Destroy(renderTextures[i]);
				renderTextures[i] = null;
			}

			ready = false;
		}
		
		public void Invoke(KernelEnum kernel, BufferEnum buffer)
		{
			Graphics.Blit(null, GetWorkingBuffer(buffer), material, getKernelIndex(kernel));
		}
		
		public void SwapBuffers()
		{
			swapFlag = !swapFlag;
		}

		//用 如:[A~C,D~F] 二分法去选择某个区间块的RT
		public RenderTexture GetLastBuffer(BufferEnum buffer)
		{
			var index = getBufferIndex(buffer);
			return renderTextures[swapFlag ? index + renderTextures.Length / 2 : index];
		}

		public RenderTexture GetWorkingBuffer(BufferEnum buffer)
		{
			var index = getBufferIndex(buffer);
			return renderTextures[swapFlag ? index : index + renderTextures.Length / 2];
		}
	}
}