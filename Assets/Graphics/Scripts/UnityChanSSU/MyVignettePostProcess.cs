using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	public enum VignetteMode
	{
		Classic,
		Masked,
	}

	[Serializable]
	public sealed class VignetteModeParameter : VolumeParameter<VignetteMode>
	{
		public VignetteModeParameter(VignetteMode value, bool overrideState = false)
			: base(value, overrideState)
		{
		}
	}

	[Serializable, VolumeComponentMenu("My/MyVignette")]
	public class MyVignettePostProcess : VolumeComponent, IPostProcessComponent
	{
		/// <summary>
		/// Use the \"Classic\" mode for parametric controls. Use the \"Masked\" mode to use your own texture mask.
		/// </summary>
		[Tooltip(
			"Use the \"Classic\" mode for parametric controls. Use the \"Masked\" mode to use your own texture mask.")]
		public VignetteModeParameter mode = new VignetteModeParameter(VignetteMode.Classic);

		/// <summary>
		/// The color to use to tint the vignette.
		/// </summary>
		[Tooltip("Vignette color.")] public ColorParameter color = new ColorParameter
			(new Color(0f, 0f, 0f, 1f));

		/// <summary>
		/// Sets the vignette center point (screen center is <c>[0.5,0.5]</c>).
		/// </summary>
		[Tooltip("Sets the vignette center point (screen center is [0.5, 0.5]).")]
		public Vector2Parameter center = new Vector2Parameter(new Vector2(0.5f, 0.5f));

		/// <summary>
		/// The amount of vignetting on screen.
		/// </summary>
		[Tooltip("Amount of vignetting on screen.")]
		public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);

		/// <summary>
		/// The smoothness of the vignette borders.
		/// </summary>
		[Tooltip("Smoothness of the vignette borders.")]
		public ClampedFloatParameter smoothness = new ClampedFloatParameter(0.2f, 0.01f, 1f);

		/// <summary>
		/// Lower values will make a square-ish vignette.
		/// </summary>
		[Tooltip("Lower values will make a square-ish vignette.")]
		public ClampedFloatParameter roundness = new ClampedFloatParameter(1f, 0f, 1f);

		/// <summary>
		/// Should the vignette be perfectly round or be dependent on the current aspect ratio?
		/// </summary>
		[Tooltip(
			"Set to true to mark the vignette to be perfectly round. False will make its shape dependent on the current aspect ratio.")]
		public BoolParameter rounded = new BoolParameter(false);

		/// <summary>
		/// A black and white mask to use as a vignette.
		/// </summary>
		[Tooltip("A black and white mask to use as a vignette.")]
		public TextureParameter mask = new TextureParameter(null);

		/// <summary>
		/// Mask opacity.
		/// </summary>
		[Range(0f, 1f), Tooltip("Mask opacity.")]
		public ClampedFloatParameter opacity = new ClampedFloatParameter(1f, 0f, 1f);

		public bool IsActive() => (mode.value == VignetteMode.Classic && intensity.value > 0f)
		                          || (mode.value == VignetteMode.Masked && opacity.value > 0f && mask.value != null);

		public bool IsTileCompatible() => false;
	}
}