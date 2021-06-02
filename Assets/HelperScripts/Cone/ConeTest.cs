using System;
using UnityEngine;

namespace HelperScripts.Cone
{
	public class ConeTest : MonoBehaviour
	{
		public Transform prefab;

		[Range(0, 100f)] public float height = 10f;

		[Min(0)] public float radiusSpeed = 1f;
		[Min(0)] public float angleSpeed = 1f;
		[Min(0)] public int count = 1000;

		[Range(0, 1f)] public float percent = 1f;

		private Transform[] gos;

		private void Start()
		{
			gos = new Transform[count];

			for (int i = 0; i < count; i++)
			{
				gos[i] = GameObject.Instantiate(prefab);
			}
		}

		public void Update()
		{
			float step = 1f / count;
			int showCount = (int) (count * percent);
			for (int i = 0; i < count; i++)
			{
				var go = gos[i];

				if (i <= showCount)
				{
					// go.localScale = prefab.localScale;
					if (!go.gameObject.activeSelf)
					{
						go.gameObject.SetActive(true);
					}
				}
				else
				{
					// go.localScale = Vector3.zero;
					if (go.gameObject.activeSelf)
					{
						go.gameObject.SetActive(false);
					}
				}

				float t = (float) i / count;

				t = Mathf.Sqrt(t);

				float x = radiusSpeed * t * Mathf.Cos(angleSpeed * t);
				float z = radiusSpeed * t * Mathf.Sin(angleSpeed * t);
				float y = Mathf.Lerp(height, 0, t);

				go.position = new Vector3(x, y, z);
			}
		}
	}
}