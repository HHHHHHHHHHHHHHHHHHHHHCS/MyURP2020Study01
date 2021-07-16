using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing
{
	public abstract class AbsXPostProcessingParameters : VolumeComponent, IPostProcessComponent
	{
		protected abstract string k_tag { get; }
		public ProfilingSampler profilingSampler { get; protected set; }

		public abstract bool IsActive();

		public abstract bool IsTileCompatible();

		public abstract void Execute(XPostProcessAssets assets, RTHelper rtHelper,
			CommandBuffer cmd, ScriptableRenderContext context, ref RenderingData renderingData,
			out bool swapRT);
	}
}