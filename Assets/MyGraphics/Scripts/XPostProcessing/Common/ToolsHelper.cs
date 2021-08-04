using System;
using System.Diagnostics;
using UnityEngine;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;

namespace MyGraphics.Scripts.XPostProcessing.Common
{
	[Serializable, DebuggerDisplay(k_DebuggerDisplay)]
	public sealed class EnumParameter<T> : VolumeParameter<T>
		where T : Enum
	{
		public EnumParameter(T value, bool overrideState = false)
			: base(value, overrideState)
		{
		}
	}

	public static class ToolsHelper
	{
		public static bool CreateMaterial(ref Shader shader, ref Material material)
		{
			if (shader == null)
			{
				if (material != null)
				{
					CoreUtils.Destroy(material);
					material = null;
				}

				Debug.LogError("Shader is null,can't create!");
				return false;
			}

			if (material == null)
			{
				material = CoreUtils.CreateEngineMaterial(shader);
			}
			else if (material.shader != shader)
			{
				//这里用重建 就是怕material属性残留污染
				//不然可以直接这样 material.shader = shader;
				CoreUtils.Destroy(material);
				material = CoreUtils.CreateEngineMaterial(shader);
			}

			return true;
		}

		public static Material GetCreateMaterial(ref Shader shader, ref Material material)
		{
			DestroyMaterial(ref material);
			CreateMaterial(ref shader, ref material);
			return material;
		}


		public static void DestroyMaterial(ref Material mat)
		{
			if (mat != null)
			{
				CoreUtils.Destroy(mat);
				mat = null;
			}
		}
	}
}