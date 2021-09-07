using System;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
	public class SkinnerTrail : MonoBehaviour
	{
		public static SkinnerTrail Instance { get; private set; }
		
		[SerializeField] [Tooltip("Reference to a template object used for rendering trail lines.")]
		public SkinnerTrailTemplate template;

		//Dynamics settings
		//----------------------------------

		[SerializeField, Tooltip("Limits an amount of a vertex movement. This only affects changes " +
		                         "in vertex positions (doesn't change velocity vectors).")]
		private float speedLimit = 0.4f;

		[SerializeField, Tooltip("Drag coefficient (damping coefficient).")]
		private float drag = 5;

		//Line width modifier
		//----------------------------------

		[SerializeField, Tooltip("Part of lines under this speed will be culled.")]
		private float cutoffSpeed = 0;

		[SerializeField, Tooltip("Increases the line width based on its speed.")]
		private float speedToWidth = 0.02f;


		[SerializeField, Tooltip("The maximum width of lines.")]
		private float maxWidth = 0.05f;

		//Other settings
		//----------------------------------

		[SerializeField, Tooltip("Determines the random number sequence used for the effect.")]
		private int randomSeed = 0;

		private bool reconfigured;

		public SkinnerTrailTemplate Template
		{
			get => template;
			set
			{
				template = value;
				Reconfigured = true;
			}
		}

		/// Limits an amount of a vertex movement. This only affects changes
		/// in vertex positions (doesn't change velocity vectors).
		public float SpeedLimit
		{
			get => speedLimit;
			set => speedLimit = value;
		}

		/// Drag coefficient (damping coefficient).
		public float Drag
		{
			get => drag;
			set => drag = value;
		}

		/// Part of lines under this speed will be culled.
		public float CutoffSpeed
		{
			get => cutoffSpeed;
			set => cutoffSpeed = value;
		}

		/// Increases the line width based on its speed.
		public float SpeedToWidth
		{
			get => speedToWidth;
			set => speedToWidth = value;
		}

		/// The maximum width of lines.
		public float MaxWidth
		{
			get => maxWidth;
			set => maxWidth = value;
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

		public bool Reconfigured
		{
			get => reconfigured;
			set => reconfigured = value;
		}


		private void OnEnable()
		{
			Instance = this;
		}

		private void OnDisable()
		{
			Instance = null;
		}
	}
}