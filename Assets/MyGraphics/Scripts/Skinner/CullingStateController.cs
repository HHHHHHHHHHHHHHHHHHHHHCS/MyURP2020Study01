using System;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	[AddComponentMenu("")] // Hidden from the component menu.
	public class CullingStateController : MonoBehaviour
	{
		public Renderer target { get; set; }

		private void OnPreCull()
		{
			target.enabled = true;
		}

		private void OnPostRender()
		{
			target.enabled = false;
		}
	}
}