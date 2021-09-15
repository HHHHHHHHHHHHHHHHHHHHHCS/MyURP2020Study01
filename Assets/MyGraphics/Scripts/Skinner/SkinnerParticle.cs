using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class SkinnerParticle : MonoBehaviour, ISkinnerSetting
	{
		[SerializeField] private Material mat;

		[SerializeField] private SkinnerSource source;

		[SerializeField, Tooltip("Reference to a template object used for rendering particles.")]
		private SkinnerParticleTemplate template;

		[SerializeField] public bool useMRT;

		//Basic dynamics settings
		//----------------------------------
		[SerializeField,
		 Tooltip(
			 "Limits speed of particles. This only affects changes in particle positions (doesn't modify velocity vectors).")]
		private float speedLimit = 1.0f;

		[SerializeField, Range(0, 15), Tooltip("The drag (damping) coefficient.")]
		private float drag = 0.1f;

		[SerializeField, Tooltip("The constant acceleration.")]
		private Vector3 gravity = Vector3.zero;

		//Particle life (duration) settings
		//-------------------------------
		[SerializeField, Min(0.0f), Tooltip("Changes the duration of a particle based on its initial speed.")]
		private float speedToLife = 4.0f;

		[SerializeField, Min(0.01f), Tooltip("The maximum duration of particles.")]
		private float maxLife = 4.0f;

		//Spin (rotational movement) settings
		//-------------------------------
		[SerializeField, Tooltip("Changes the angular velocity of a particle based on its speed.")]
		private float speedToSpin = 60.0f;

		[SerializeField, Tooltip("The maximum angular velocity of particles.")]
		private float maxSpin = 20.0f;

		//Particle scale settings
		//-----------------------------------
		[SerializeField, Min(0.0f), Tooltip("Changes the scale of a particle based on its initial speed.")]
		private float speedToScale = 0.5f;

		[SerializeField, Min(0.0f), Tooltip("The maximum scale of particles.")]
		private float maxScale = 1.0f;

		//Turbulent noise settings
		//-----------------------------
		[SerializeField, Tooltip("The amplitude of acceleration from the turbulent noise field.")]
		private float noiseAmplitude = 1.0f;

		[SerializeField, Tooltip("The spatial frequency of the turbulent noise field.")]
		private float noiseFrequency = 0.2f;

		[SerializeField, Tooltip("Determines how fast the turbulent noise field changes.")]
		private float noiseMotion = 1.0f;

		[SerializeField, Tooltip("Determines the random number sequence used for the effect.")]
		private int randomSeed = 0;

		//Reconfiguration detection
		//---------------------------
		private bool reconfigured;

		private bool resetMat;

		private SkinnerData data;
		

		public SkinnerSource Source
		{
			get => source;
			set
			{
				source = value;
				reconfigured = true;
			}
		}

		/// Reference to a template object used for rendering particles.
		public SkinnerParticleTemplate Template
		{
			get => template;
			set
			{
				template = value;
				reconfigured = true;
			}
		}

		public float SpeedLimit
		{
			get => speedLimit;
			set => speedLimit = value;
		}

		/// The drag (damping) coefficient.
		public float Drag
		{
			get => drag;
			set => drag = value;
		}

		public Vector3 Gravity
		{
			get => gravity;
			set => gravity = value;
		}

		public float SpeedToLife
		{
			get => speedToLife;
			set => speedToLife = Mathf.Max(value, 0.0f);
		}

		/// The maximum duration of particles.
		public float MaxLife
		{
			get => maxLife;
			set => maxLife = Mathf.Max(value, 0.01f);
		}

		public float SpeedToSpin
		{
			get => speedToSpin;
			set => speedToSpin = value;
		}

		public float MaxSpin
		{
			get => maxSpin;
			set => maxSpin = value;
		}

		public float SpeedToScale
		{
			get => speedToScale;
			set
			{
				speedToScale = Mathf.Max(value, 0.0f);
				resetMat = true;
			}
		}

		public float MaxScale
		{
			get => maxScale;
			set
			{
				maxScale = Mathf.Max(value, 0.0f);
				resetMat = true;
			}
		}

		/// The amplitude of acceleration from the turbulent noise.
		public float NoiseAmplitude
		{
			get => noiseAmplitude;
			set => noiseAmplitude = value;
		}

		public float NoiseFrequency
		{
			get => noiseFrequency;
			set => noiseFrequency = value;
		}

		public float NoiseMotion
		{
			get => noiseMotion;
			set => noiseMotion = value;
		}

		public int RandomSeed
		{
			get => randomSeed;
			set
			{
				randomSeed = value;
				reconfigured = true;
			}
		}

		public bool Reconfigured
		{
			get => reconfigured;
		}

		public SkinnerData Data => data;
		public Material Mat => mat;
		public bool UseMRT => useMRT;
		public int Width => Template == null ? 0 : Template.InstanceCount;
		public int Height => 1;
		public bool CanRender =>
			mat != null && template != null && source != null && source.CanRender;


		private void OnEnable()
		{
			if (!CanRender)
			{
				return;
			}

			GetComponent<MeshFilter>().mesh = template.Mesh;
			GetComponent<MeshRenderer>().material = mat;
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
				mat.SetVector(SkinnerShaderConstants.Scale_ID, new Vector4(maxScale, speedToScale, 0, 0));
			}

			if (data.HaveRTs)
			{
				mat.SetTexture(SkinnerShaderConstants.ParticlePositionTex_ID, data.CurrTex(ParticlesRTIndex.Position));
				mat.SetTexture(SkinnerShaderConstants.ParticleVelocityTex_ID, data.CurrTex(ParticlesRTIndex.Velocity));
				mat.SetTexture(SkinnerShaderConstants.ParticleRotationTex_ID, data.CurrTex(ParticlesRTIndex.Rotation));
				mat.SetTexture(SkinnerShaderConstants.ParticlePrevPositionTex_ID,
					data.PrevTex(ParticlesRTIndex.Position));
				mat.SetTexture(SkinnerShaderConstants.ParticlePrevRotationTex_ID,
					data.PrevTex(ParticlesRTIndex.Rotation));
			}
		}
	}
}