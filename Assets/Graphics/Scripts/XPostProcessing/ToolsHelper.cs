using System;
using System.Diagnostics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using Debug = UnityEngine.Debug;

namespace Graphics.Scripts.XPostProcessing
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
	}
}