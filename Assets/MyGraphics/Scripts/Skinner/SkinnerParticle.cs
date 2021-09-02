using System;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshRenderer))]
	public class SkinnerParticle : MonoBehaviour
	{
		public static SkinnerParticle Instance { get; private set; }
		
		[SerializeField, Tooltip("Reference to a template object used for rendering particles.")]
		private SkinnerParticleTemplate template;

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
		[SerializeField, Tooltip("Changes the duration of a particle based on its initial speed.")]
		private float speedToLife = 4.0f;

		[SerializeField, Tooltip("The maximum duration of particles.")]
		private float maxLife = 4.0f;

		//Spin (rotational movement) settings
		//-------------------------------
		[SerializeField, Tooltip("Changes the angular velocity of a particle based on its speed.")]
		private float speedToSpin = 60.0f;

		[SerializeField, Tooltip("The maximum angular velocity of particles.")]
		private float maxSpin = 20.0f;

		//Particle scale settings
		//-----------------------------------
		[SerializeField, Tooltip("Changes the scale of a particle based on its initial speed.")]
		private float speedToScale = 0.5f;

		[SerializeField, Tooltip("The maximum scale of particles.")]
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

		//Built-in assets
		//-------------------------------
		[SerializeField] private Shader kernelShader;
		[SerializeField] private Material defaultMaterial;

		//Reconfiguration detection
		//---------------------------
		private bool reconfigured;

		// Local state variables.
		private Vector3 noiseOffset;


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
			set => speedToLife = value;
		}

		/// The maximum duration of particles.
		public float MaxLife
		{
			get => maxLife;
			set => maxLife = value;
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
			set => speedToScale = value;
		}

		public float MaxScale
		{
			get => maxScale;
			set => maxScale = value;
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

		private void OnEnable()
		{
			Instance = this;
		}

		private void OnDisable()
		{
			Instance = null;
		}

		private void OnValidate()
		{
			SpeedToLife = Mathf.Max(SpeedToLife, 0.0f);
			MaxLife = Mathf.Max(MaxLife, 0.01f);

			SpeedToScale = Mathf.Max(SpeedToScale, 0.0f);
			MaxScale = Mathf.Max(MaxScale, 0.0f);
		}

		private void Reset()
		{
			reconfigured = true;
		}
	}
}