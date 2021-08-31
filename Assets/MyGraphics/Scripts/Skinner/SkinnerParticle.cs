using System;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshRenderer))]
	public class SkinnerParticle : MonoBehaviour
	{
		//Animation kernels management
		//-----------------------
		private enum Kernels
		{
			InitializePosition,
			InitializeVelocity,
			InitializeRotation,
			UpdatePosition,
			UpdateVelocity,
			UpdateRotation
		}

		private enum Buffers
		{
			Position,
			Velocity,
			Rotation
		}

		//External object/asset references
		//---------------------------------------
		[SerializeField, Tooltip("Reference to an effect source.")]
		private SkinnerSource source;

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

		private AnimationKernelSet<Kernels, Buffers> kernel;

		// Local state variables.
		private Vector3 noiseOffset;

		private RendererAdapter rendererAdapter;

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

		private void LateUpdate()
		{
			if (Source == null)// || !Source.IsReady)
			{
				return;
			}

			if (reconfigured)
			{
				kernel?.Release();
				reconfigured = false;
			}
			
			InvokeAnimationKernels();
			UpdateRenderer();
		}

		private void OnDestroy()
		{
			kernel.Release();
		}

		private void OnValidate()
		{
			SpeedToLife = Mathf.Max(SpeedToLife, 0.0f);
			MaxLife = Mathf.Max(MaxLife, 0.01f);
			
			SpeedToScale = Mathf.Max(SpeedToScale, 0.0f);
			MaxScale = Mathf.Max(MaxScale, 0.0f);
		}

		private void InvokeAnimationKernels()
		{
			if (kernel == null)
			{
				kernel = new AnimationKernelSet<Kernels, Buffers>(kernelShader, x => (int) x, y => (int) y);
			}

			if (!kernel.Ready)
			{
				kernel.Setup(Template.InstanceCount, 1);
				kernel.Material.SetTexture("_SourcePositionBuffer1", Source.PositionTex);
				kernel.Material.SetFloat("_RandomSeed", RandomSeed);
				kernel.Invoke(Kernels.InitializePosition, Buffers.Position);
				kernel.Invoke(Kernels.InitializeVelocity, Buffers.Velocity);
				kernel.Invoke(Kernels.InitializeRotation, Buffers.Rotation);
			}
			else
			{
				float dt = Time.deltaTime;
				kernel.Material.SetVector("_Damper", new Vector2(
					Mathf.Exp(-Drag * dt), SpeedLimit
				));
				kernel.Material.SetVector("_Gravity", Gravity * dt);
				kernel.Material.SetVector("_Life", new Vector2(dt / MaxLife, dt / (MaxLife * speedToLife)));
				var pi360dt = Mathf.PI * dt / 360.0f;
				kernel.Material.SetVector("_Spin", new Vector2(
					MaxSpin * pi360dt, SpeedToSpin * pi360dt
				));
				kernel.Material.SetVector("_NoiseParams", new Vector2(
					NoiseFrequency, NoiseAmplitude * dt
				));

				// Move the noise field backward in the direction of the
				// gravity vector, or simply pull up if no gravity is set.
				var noiseDir = (Gravity == Vector3.zero) ? Vector3.up : Gravity.normalized;
				noiseOffset += noiseDir * NoiseMotion * dt;
				kernel.Material.SetVector("_NoiseOffset", noiseOffset);

				// Transfer the source position attributes.
				kernel.Material.SetTexture("_SourcePositionBuffer0", source.PreviousPositionTex);
				kernel.Material.SetTexture("_SourcePositionBuffer1", source.PositionTex);

				// Invoke the position update kernel.
				kernel.Material.SetTexture("_PositionBuffer", kernel.GetLastBuffer(Buffers.Position));
				kernel.Material.SetTexture("_VelocityBuffer", kernel.GetLastBuffer(Buffers.Velocity));
				kernel.Invoke(Kernels.UpdatePosition, Buffers.Position);

				// Invoke the velocity update kernel with the updated positions.
				kernel.Material.SetTexture("_PositionBuffer", kernel.GetWorkingBuffer(Buffers.Position));
				kernel.Invoke(Kernels.UpdateVelocity, Buffers.Velocity);

				// Invoke the rotation update kernel with the updated velocity.
				kernel.Material.SetTexture("_RotationBuffer", kernel.GetLastBuffer(Buffers.Rotation));
				kernel.Material.SetTexture("_VelocityBuffer", kernel.GetWorkingBuffer(Buffers.Velocity));
				kernel.Invoke(Kernels.UpdateRotation, Buffers.Rotation);
			}

			kernel.SwapBuffers();
		}

		private void UpdateRenderer()
		{
			if (rendererAdapter == null)
			{
				rendererAdapter = new RendererAdapter(gameObject, defaultMaterial);
			}

			var block = rendererAdapter.PropertyBlock;
			block.SetTexture("_PreviousPositionBuffer", kernel.GetWorkingBuffer(Buffers.Position));
			block.SetTexture("_PreviousRotationBuffer", kernel.GetWorkingBuffer(Buffers.Position));
			block.SetTexture("_PositionBuffer", kernel.GetLastBuffer(Buffers.Position));
			block.SetTexture("_VelocityBuffer", kernel.GetLastBuffer(Buffers.Velocity));
			block.SetTexture("_RotationBuffer", kernel.GetLastBuffer(Buffers.Rotation));
			block.SetVector("_Scale", new Vector2(MaxScale, SpeedToScale));
			block.SetFloat("_RandomSeed", RandomSeed);
			
			rendererAdapter.Update(Template.Mesh);
		}
		
		private void Reset()
		{
			reconfigured = true;
		}

		public void UpdateConfiguration()
		{
			reconfigured = true;
		}
	}
}