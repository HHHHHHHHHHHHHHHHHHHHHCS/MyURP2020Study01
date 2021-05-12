using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.AtmosphericScattering
{
	[ExecuteInEditMode]
	public class ScatteringSetting : MonoBehaviour
	{
		public float distanceScale = 1.0f;

		//Rayleign
		public Vector3 rCoef = new Vector3(5.8f, 13.5f, 33.1f);
		public float rScatterStrength = 1f;
		public float rExtinctionStrength = 1f;

		//Mie
		public Vector3 mCoef = new Vector3(2.0f, 2.0f, 2.0f);
		public float mScatterStrength = 1f;
		public float mExtinctionStrength = 1f;
		public float mieG = 0.625f;

		[Header("Debug")] public DebugMode debugMode;

		// public bool lightShaft = true;

		private void Update()
		{
			UpdateParams();
		}

		private void UpdateParams()
		{
			SetKeyword(IDKeys.kDebugExtinction, debugMode == DebugMode.Extinction);
			SetKeyword(IDKeys.kDebugInscattering, debugMode == DebugMode.Inscattering);

			Shader.SetGlobalFloat(IDKeys.DistanceScale_ID, distanceScale);
			//地球的数据：
			//private readonly Vector4 _rayleighSct = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f; 
			//private readonly Vector4 _mieSct = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f; 
			var _rCoef = rCoef * 0.000001f;
			var _mCoef = mCoef * 0.00001f;
			Shader.SetGlobalVector(IDKeys.ScatteringR_ID, _rCoef * rScatterStrength);
			Shader.SetGlobalVector(IDKeys.ScatteringM_ID, _mCoef * mScatterStrength);
			Shader.SetGlobalVector(IDKeys.ExtinctionR_ID, _rCoef * rExtinctionStrength);
			Shader.SetGlobalVector(IDKeys.ExtinctionM_ID, _mCoef * mExtinctionStrength);
			Shader.SetGlobalFloat(IDKeys.MieG_ID, mieG);

			// SetKeyword(IDKeys.kLightShaft, lightShaft);
		}

		private void SetKeyword(string idKey, bool bl)
		{
			if (bl)
			{
				Shader.EnableKeyword(idKey);
			}
			else
			{
				Shader.DisableKeyword(idKey);
			}
		}
	}
}