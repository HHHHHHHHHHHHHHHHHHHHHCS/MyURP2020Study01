using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerRenderContainer<TCls, TEnum> : ISkinnerContainer<TCls>
		where TCls : ISkinnerSetting
		where TEnum : Enum
	{
		private List<TCls> skinners;

		public List<TCls> Skinners => skinners;
		public bool CanDestroy => skinners.Count == 0;


		public SkinnerRenderContainer()
		{
			skinners = new List<TCls>();
		}

		public void Update()
		{
			foreach (var item in skinners)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs(item);
				item.UpdateMat();
			}
		}

		public void AfterRendering()
		{
			foreach (var item in skinners)
			{
				if (!item.Source.Data.isFirst)
				{
					item.Data.isFirst = false;
				}
			}
		}

		public void Register(TCls obj)
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

		public void Remove(TCls obj)
		{
			if (skinners.Remove(obj))
			{
				DestroyRTs(obj.Data.RTs);
			}
		}

		public void CheckRTs(TCls obj)
		{
			CheckRTs<TEnum>(obj);
		}

		private void CheckRTs<T>(ISkinnerSetting setting) where T : Enum
		{
			RenderTexture[] rts = setting.Data.RTs;
			int width = setting.Width;
			int height = setting.Height;
			bool isForce = setting.Reconfigured;

			if (!isForce && rts != null && rts[0] != null && rts[0].width == width && rts[0].height == height)
			{
				return;
			}

			if (width == 0 || height == 0)
			{
				DestroyRTs(rts);
				setting.Data.RTs = null;
				return;
			}

			setting.Data.isFirst = true;
			setting.Data.isSwap = false;

			var names = Enum.GetNames(typeof(T));
			var len = names.Length;
			if (rts == null)
			{
				rts = new RenderTexture[len * 2];
			}
			else
			{
				DestroyRTs(rts);
			}

			//为什么不用R11B11G10 因为不支持负数  
			RenderTextureDescriptor rtd =
				new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGBHalf, 0, 1);

			for (int i = 0; i < len; i++)
			{
				rts[i] = new RenderTexture(rtd)
				{
					filterMode = FilterMode.Point,
					name = names[i] + "0"
				};
				rts[len + i] = new RenderTexture(rtd)
				{
					filterMode = FilterMode.Point,
					name = names[i] + "1"
				};
			}

			setting.Data.RTs = rts;
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