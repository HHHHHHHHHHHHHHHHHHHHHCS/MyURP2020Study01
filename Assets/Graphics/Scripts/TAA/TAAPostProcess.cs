using System;
using System.Diagnostics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.TAA
{
	public enum Neighborhood
	{
		MinMax3x3,
		MinMax3x3Rounded,
		MinMax4TapVarying,
	}

	[Serializable, DebuggerDisplay(k_DebuggerDisplay)]
	public sealed class EnumParameter<T> : VolumeParameter<T>
		where T : Enum
	{
		public EnumParameter(T value, bool overrideState = false)
			: base(value, overrideState)
		{
		}
	}


	[Serializable, VolumeComponentMenu("My/TAA")]
	public class TAAPostProcess : VolumeComponent, IPostProcessComponent
	{
		public BoolParameter enableEffect = new BoolParameter(false);

		[Header("FrustumJitter")]
		public EnumParameter<Pattern> pattern = new EnumParameter<Pattern>(Pattern.Halton_2_3_X16);

		public FloatParameter patternScale = new FloatParameter(1.0f);

		//代码传入settings  传给其它类用
		[NonSerialized, HideInInspector]
		public Vector4 activeSample = Vector4.zero; // xy = current sample, zw = previous sample

		[Header("VelocityBuffer")] public BoolParameter neighborMaxGen = new BoolParameter(false);

		public EnumParameter<NeighborMaxSupport> neighborMaxSupport =
			new EnumParameter<NeighborMaxSupport>(NeighborMaxSupport.TileSize20);


		[Header("TemporalReprojection")] public EnumParameter<Neighborhood>
			neighborhood = new EnumParameter<Neighborhood>(Neighborhood.MinMax3x3Rounded);

		public BoolParameter unjitterColorSamples = new BoolParameter(true);
		public BoolParameter unjitterNeighborhood = new BoolParameter(false);
		public BoolParameter unjitterReprojection = new BoolParameter(false);
		public BoolParameter useYCoCg = new BoolParameter(false);
		public BoolParameter useClipping = new BoolParameter(true);
		public BoolParameter useDilation = new BoolParameter(true);
		public BoolParameter useMotionBlur = new BoolParameter(true);
		public BoolParameter useOptimizations = new BoolParameter(true);
		public ClampedFloatParameter feedbackMin = new ClampedFloatParameter(0.88f, 0f, 1f);
		public ClampedFloatParameter feedbackMax = new ClampedFloatParameter(0.97f, 0f, 1f);
		public FloatParameter motionBlurStrength = new FloatParameter(1f);
		public BoolParameter motionBlurIgnoreFF = new BoolParameter(false);


		public bool IsActive() => enableEffect.value;

		public bool IsTileCompatible() => false;
	}
}