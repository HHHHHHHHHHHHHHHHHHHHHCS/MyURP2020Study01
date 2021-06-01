using System;
using UnityEngine;

namespace HelperScripts.Cone
{
	public class ConeTest : MonoBehaviour
	{
		public Transform sphere;

		[Range(0, 100f)] public float height = 10f;

		[Min(0)] public float radiusSpeed = 1f;
		[Min(0)] public float angleSpeed = 1f;

		[Min(0)] public int count = 1000;

		private Transform[] gos;

		private void Start()
		{
			gos = new Transform[count];

			for (int i = 0; i < count; i++)
			{
				gos[i] = GameObject.Instantiate(sphere);
			}
		}

		public void Update()
		{
			float step = 1f / count;
			float t = -step;
			for (int i = 0; i < count; i++)
			{
				t += step;

				var go = gos[i];

				float x = radiusSpeed * t * Mathf.Cos(angleSpeed * t);
				float z = radiusSpeed * t * Mathf.Sin(angleSpeed * t);
				float y = Mathf.Lerp(height, 0, t);

				go.position = new Vector3(x, y, z);
			}
		}
	}
}