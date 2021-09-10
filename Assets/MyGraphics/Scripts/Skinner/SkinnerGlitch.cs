using System;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class SkinnerGlitch : MonoBehaviour, ISkinnerSetting
	{
		//Public properties
		//---------------------------------------------

		[SerializeField] private Material mat;

		[SerializeField, Tooltip("Reference to an effect source.")]
		private SkinnerSource source;

		[SerializeField] private SkinnerGlitchTemplate template;

		[SerializeField, Range(1, 1024), Tooltip("Length of the frame history buffer.")]
		private int historyLength = 256;

		[SerializeField, Range(0, 1), Tooltip("Determines how an effect element inherit a source velocity.")]
		private float velocityScale = 0.2f;

		[SerializeField, Min(0), Tooltip("Triangles that have longer edges than this value will be culled.")]
		private float edgeThreshold = 0.75f;

		[SerializeField, Min(0), Tooltip("Triangles that have larger area than this value will be culled.")]
		private float areaThreshold = 0.02f;

		[SerializeField, Tooltip("Determines the random number sequence used for the effect.")]
		private int randomSeed = 0;

		private bool reconfigured;
		private bool resetMat;

		private SkinnerData data;

		public Material Mat => mat;
		public int Width => source == null || source.Model == null ? 0 : source.Model.VertexCount;
		public int Height => historyLength;

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
				historyLength = Mathf.Clamp(value, 1, 1024);
				reconfigured = true;
				resetMat = true;
			}
		}


		/// Determines how an effect element inherit a source velocity.
		public float VelocityScale
		{
			get => velocityScale;
			set { velocityScale = Mathf.Clamp01(value); }
		}

		/// Triangles that have longer edges than this value will be culled.
		public float EdgeThreshold
		{
			get => edgeThreshold;
			set
			{
				edgeThreshold = Mathf.Max(value, 0);
				resetMat = true;
			}
		}

		/// Triangles that have larger area than this value will be culled.
		public float AreaThreshold
		{
			get => areaThreshold;
			set
			{
				areaThreshold = Mathf.Max(value, 0);
				resetMat = true;
			}
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

		public SkinnerData Data => data;
		public bool CanRender => mat != null && template != null && source != null && source.Model != null;

		private void OnEnable()
		{
			if (!CanRender)
			{
				return;
			}

			GetComponent<MeshFilter>().mesh = template.Mesh;
			data = new SkinnerData()
			{
				mat = mat
			};
			reconfigured = true;
			resetMat = true;
			SkinnerManager.Instance.Register(this);
		}

		private void OnDisable()
		{
			SkinnerManager.Instance.Remove(this);
		}


		private void Reset()
		{
			reconfigured = true;
			resetMat = true;
		}

		// private void OnValidate()
		// {
		// 	reconfigured = true;
		// 	resetMat = true;
		// }

		public void UpdateMat()
		{
			reconfigured = false;
			if (resetMat)
			{
				resetMat = false;
				mat.SetFloat(SkinnerShaderConstants.EdgeThreshold_ID, edgeThreshold);
				mat.SetFloat(SkinnerShaderConstants.AreaThreshold_ID, areaThreshold);
				mat.SetFloat(SkinnerShaderConstants.RandomSeed_ID, randomSeed);
				mat.SetFloat(SkinnerShaderConstants.BufferOffset_ID, Time.frameCount);
			}

			if (data.rts != null)
			{
				mat.SetTexture(SkinnerShaderConstants.GlitchPositionTex_ID,
					data.CurrTex(GlitchRTIndex.Position));
				mat.SetTexture(SkinnerShaderConstants.GlitchVelocityTex_ID,
					data.CurrTex(GlitchRTIndex.Velocity));
				mat.SetTexture(SkinnerShaderConstants.GlitchPrevPositionTex_ID,
					data.PrevTex(GlitchRTIndex.Position));
				mat.SetTexture(SkinnerShaderConstants.GlitchPrevVelocityTex_ID,
					data.PrevTex(GlitchRTIndex.Velocity));
			}
		}
	}
}