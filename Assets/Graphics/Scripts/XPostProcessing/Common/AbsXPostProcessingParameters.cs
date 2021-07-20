using System.Collections.Generic;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing.Common
{
	public abstract class AbsXPostProcessingParameters : VolumeComponent, IPostProcessComponent
	{
		public static Dictionary<string, ProfilingSampler> samplerDict = new Dictionary<string, ProfilingSampler>();

		protected abstract string k_tag { get; }

		public ProfilingSampler profilingSampler
		{
			get
			{
				if (!samplerDict.TryGetValue(k_tag,out var ps))
				{
					ps = new ProfilingSampler(k_tag);
					samplerDict.Add(k_tag,ps);
				}

				return ps;
			}
		}

		public static void ClearSamplerDict()
		{
			samplerDict.Clear();
		}

		public abstract bool IsActive();
		public abstract int PriorityQueue();

		public abstract bool IsTileCompatible();

		public abstract void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT);

	}
}