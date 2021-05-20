using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/MyBloom")]
	public class MyBloomPostProcess : VolumeComponent, IPostProcessComponent
	{
		/// <summary>
		/// The strength of the bloom filter.
		/// </summary>
		[Tooltip(
			"Strength of the bloom filter. Values higher than 1 will make bloom contribute more energy to the final render.")]
		public MinFloatParameter intensity = new MinFloatParameter(0f, 0f);

		/// <summary>
		/// Filters out pixels under this level of brightness. This value is expressed in
		/// gamma-space.
		/// </summary>
		[Tooltip("Filters out pixels under this level of brightness. Value is in gamma-space.")]
		public MinFloatParameter threshold = new MinFloatParameter(0f, 0f);

		/// <summary>
		/// Makes transition between under/over-threshold gradual (0 = hard threshold, 1 = soft
		/// threshold).
		/// </summary>
		[Tooltip(
			"Makes transitions between under/over-threshold gradual. 0 for a hard threshold, 1 for a soft threshold).")]
		public ClampedFloatParameter softKnee = new ClampedFloatParameter(0.5f, 0f, 1f);

		/// <summary>
		/// Clamps pixels to control the bloom amount. This value is expressed in gamma-space.
		/// </summary>
		[Tooltip("Clamps pixels to control the bloom amount. Value is in gamma-space.")]
		public FloatParameter clamp = new FloatParameter(65472f);

		/// <summary>
		/// Changes extent of veiling effects in a screen resolution-independent fashion. For
		/// maximum quality stick to integer values. Because this value changes the internal
		/// iteration count, animating it isn't recommended as it may introduce small hiccups in
		/// the perceived radius.
		/// </summary>
		[Tooltip(
			"Changes the extent of veiling effects. For maximum quality, use integer values. Because this value changes the internal iteration count, You should not animating it as it may introduce issues with the perceived radius.")]
		public ClampedFloatParameter diffusion = new ClampedFloatParameter(7f, 1f, 10f);

		/// <summary>
		/// Distorts the bloom to give an anamorphic look. Negative values distort vertically,
		/// positive values distort horizontally.
		/// </summary>
		[Tooltip(
			"Distorts the bloom to give an anamorphic look. Negative values distort vertically, positive values distort horizontally.")]
		public ClampedFloatParameter anamorphicRatio = new ClampedFloatParameter(0f, -1f, 1f);

		/// <summary>
		/// The tint of the Bloom filter.
		/// </summary>
		[Tooltip("Global tint of the bloom filter.")]
		public ColorParameter color = new ColorParameter(Color.white, true, false, true);

		/// <summary>
		/// Boost performances by lowering the effect quality.
		/// </summary>
		[Tooltip(
			"Boost performance by lowering the effect quality. This settings is meant to be used on mobile and other low-end platforms but can also provide a nice performance boost on desktops and consoles.")]
		public BoolParameter fastMode = new BoolParameter(false);

		/// <summary>
		/// The dirtiness texture to add smudges or dust to the lens.
		/// </summary>
		[Tooltip("The lens dirt texture used to add smudges or dust to the bloom effect.")]
		public TextureParameter dirtTexture = new TextureParameter(null);

		/// <summary>
		/// The amount of lens dirtiness.
		/// </summary>
		[Tooltip("The intensity of the lens dirtiness.")]
		public MinFloatParameter dirtIntensity = new MinFloatParameter(0f, 0f);


		public bool IsActive() => intensity.value > 0f;

		public bool IsTileCompatible() => false;
	}
}