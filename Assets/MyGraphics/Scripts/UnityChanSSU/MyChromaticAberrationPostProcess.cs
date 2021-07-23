using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.UnityChanSSU
{
	[Serializable, VolumeComponentMenu("My/MyChromaticAberration")]
	public class MyChromaticAberrationPostProcess : VolumeComponent, IPostProcessComponent
	{
		/// <summary>
		/// A texture used for custom fringing color (it will use a default one when <c>null</c>).
		/// </summary>
		[Tooltip("Shifts the hue of chromatic aberrations.")]
		public TextureParameter spectralLut = new TextureParameter(null);

		/// <summary>
		/// The amount of tangential distortion.
		/// </summary>
		[Range(0f, 1f), Tooltip("Amount of tangential distortion.")]
		public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);

		/// <summary>
		/// If <c>true</c>, it will use a faster variant of the effect for improved performances.
		/// </summary>
		[Tooltip(
			"Boost performances by lowering the effect quality. This settings is meant to be used on mobile and other low-end platforms but can also provide a nice performance boost on desktops and consoles.")]
		public BoolParameter fastMode = new BoolParameter(false);

		public bool IsActive() => intensity.value > 0f;

		public bool IsTileCompatible() => false;
	}
}