using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerSourceContainer : ISkinnerContainer<SkinnerSource>
	{
		private List<SkinnerSource> skinners;

		public List<SkinnerSource> Skinners => skinners;
		public bool CanDestroy => skinners.Count == 0;

		public SkinnerSourceContainer()
		{
			skinners = new List<SkinnerSource>();
		}
		
		public void Update()
		{
			foreach (var item in skinners)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs(item);
			}
		}

		public void AfterRendering()
		{
			foreach (var item in skinners)
			{
				item.Data.isFirst = false;
			}
		}

		public void Register(SkinnerSource obj)
		{
			if (obj == null || !obj.CanRender || obj.Data == null)
			{
				return;
			}

			if (!skinners.Contains(obj))
			{
				CheckRTs(obj);
				skinners.Add(obj);
			}
		}

		public void Remove(SkinnerSource obj)
		{
			if (skinners.Remove(obj))
			{
				DestroyRTs(obj.Data.rts);
			}
		}

		public void CheckRTs(SkinnerSource setting)
		{
			ref RenderTexture[] rts = ref setting.Data.rts;
			int width = setting.Width;
			int height = setting.Height;

			if (rts != null && rts[0] != null && rts[0].width == width && rts[0].height == height)
			{
				return;
			}

			if (width == 0 || height == 0)
			{
				DestroyRTs(rts);
				rts = null;
				return;
			}

			setting.Data.isFirst = true;
			setting.Data.isSwap = false;

			RenderTextureDescriptor rtd =
				new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGBFloat, 0, 1);

			rts = new RenderTexture[4];

			rts[VertexRTIndex.Position0] = new RenderTexture(rtd)
			{
				filterMode = FilterMode.Point,
				name = "SourcePosition0"
			};

			rts[VertexRTIndex.Position1] = new RenderTexture(rtd)
			{
				filterMode = FilterMode.Point,
				name = "SourcePosition1"
			};

			rts[VertexRTIndex.Normal] = new RenderTexture(rtd)
			{
				filterMode = FilterMode.Point,
				name = "Normal"
			};

			rts[VertexRTIndex.Tangent] = new RenderTexture(rtd)
			{
				filterMode = FilterMode.Point,
				name = "Tangent"
			};
		}

		public void DestroyRTs(RenderTexture[] rts)
		{
			if (rts == null)
			{
				return;
			}

			foreach (var rt in rts)
			{
				CoreUtils.Destroy(rt);
			}
		}
	}
}