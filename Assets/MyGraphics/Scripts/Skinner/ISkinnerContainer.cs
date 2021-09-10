using System;
using System.Collections.Generic;
using UnityEngine;

namespace MyGraphics.Scripts.Skinner
{
	public interface ISkinnerContainer<T>
	{
		public List<T> Skinners { get; }

		public bool CanDestroy { get; }

		public void Update();

		public void AfterRendering();

		public void Register(T obj);

		void Remove(T obj);
		
		void CheckRTs(T obj);

		void DestroyRTs(RenderTexture[] rts);
	}
}