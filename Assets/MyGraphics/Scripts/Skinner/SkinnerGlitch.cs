using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class SkinnerGlitch : MonoBehaviour, ISkinnerSetting
	{
		//Public properties
		//---------------------------------------------

		[SerializeField] private Material mat;

		[SerializeField] [Tooltip("Reference to an effect source.")]
		private SkinnerSource source;

		[SerializeField] private SkinnerGlitchTemplate template;

		[SerializeField] [Tooltip("Length of the frame history buffer.")]
		private int historyLength = 256;

		[SerializeField, Range(0, 1)] [Tooltip("Determines how an effect element inherit a source velocity.")]
		private float velocityScale = 0.2f;

		[SerializeField] [Tooltip("Triangles that have longer edges than this value will be culled.")]
		private float edgeThreshold = 0.75f;

		[SerializeField] [Tooltip("Triangles that have larger area than this value will be culled.")]
		private float areaThreshold = 0.02f;

		[SerializeField] [Tooltip("Determines the random number sequence used for the effect.")]
		private int randomSeed = 0;

		private bool reconfigured;


		public Material Mat => mat;
		public int Width { get; }
		public int Height { get; }

		/// Reference to an effect source.
		public SkinnerSource Source
		{
			get => source;
			set
			{
				source = value;
				reconfigured = true;
			}
		}

		public SkinnerGlitchTemplate Template
		{
			get => template;
			set
			{
				template = value;
				reconfigured = true;
			}
		}

		/// Length of the frame history buffer.
		public int HistoryLength
		{
			get => historyLength;
			set
			{
				historyLength = value;
				reconfigured = true;
			}
		}


		/// Determines how an effect element inherit a source velocity.
		public float VelocityScale
		{
			get => velocityScale;
			set => velocityScale = value;
		}

		/// Triangles that have longer edges than this value will be culled.
		public float EdgeThreshold
		{
			get => edgeThreshold;
			set => edgeThreshold = value;
		}

		/// Triangles that have larger area than this value will be culled.
		public float AreaThreshold
		{
			get => areaThreshold;
			set => areaThreshold = value;
		}


		/// Determines the random number sequence used for the effect.
		public int RandomSeed
		{
			get => randomSeed;
			set
			{
				randomSeed = value;
				reconfigured = true;
			}
		}


		/// Determines the random number sequence used for the effect.
		public bool Reconfigured => reconfigured;

		public SkinnerData Data { get; }
		public bool CanRender => mat != null && template != null && source != null && source.Model != null;


		public void UpdateMat()
		{
		}
	}
}