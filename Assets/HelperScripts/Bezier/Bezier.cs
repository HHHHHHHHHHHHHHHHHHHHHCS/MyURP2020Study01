using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace HelperScripts.Bezier
{
	public class Bezier : MonoBehaviour
	{
		public Transform prefab;
		public Transform pointParent;

		public int count = 1000;

		public LinkedList<Transform> bezierPoints;

		private Vector3[] tempPos;
		private Transform[] points;

		private void Start()
		{
			Transform parent = new GameObject("Parent").transform;
			bezierPoints = new LinkedList<Transform>();
			for (int i = 0; i < count; i++)
			{
				Transform p = Instantiate(prefab, parent, true);
				p.gameObject.SetActive(true);
				bezierPoints.AddLast(p);
			}

			tempPos = new Vector3[bezierPoints.Count];

			points = pointParent.Cast<Transform>().Select(x => x.transform).ToArray();
		}

		private void Update()
		{
			if (points == null)
			{
				return;
			}

			int len = points.Length;

			float step = 1.0f / count;
			float t = 0;
			foreach (var bp in bezierPoints)
			{
				for (int i = 0; i < points.Length; i++)
				{
					tempPos[i] = points[i].position;
				}

				t += step;
				for (int i = len - 1; i >= 0; i--)
				{
					for (int j = 0; j < i; j++)
					{
						tempPos[j] = Vector3.Lerp(tempPos[j], tempPos[j + 1], t);
					}
				}

				bp.position = tempPos[0];
			}
		}
	}
}