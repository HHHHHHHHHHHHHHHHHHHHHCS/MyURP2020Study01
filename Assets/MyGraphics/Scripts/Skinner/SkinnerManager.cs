using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public sealed class SkinnerManager
	{
		private static SkinnerManager instance;
		public static SkinnerManager Instance => instance ??= new SkinnerManager();

		private readonly List<SkinnerSource> sources;
		private readonly List<SkinnerParticle> particles;
		private readonly List<SkinnerTrail> trails;
		private readonly List<SkinnerGlitch> glitches;

		public List<SkinnerSource> Sources => sources;
		public List<SkinnerParticle> Particles => particles;
		public List<SkinnerTrail> Trails => trails;
		public List<SkinnerGlitch> Glitches => glitches;

		private SkinnerManager()
		{
			sources = new List<SkinnerSource>();
			particles = new List<SkinnerParticle>();
			trails = new List<SkinnerTrail>();
			glitches = new List<SkinnerGlitch>();
		}

		public static bool CheckInstance()
		{
			return instance != null;
		}

		public void Update()
		{
			foreach (var item in sources)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs(item);
			}

			foreach (var item in particles)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs<ParticlesRTIndex>(item);
				item.UpdateMat();
			}

			foreach (var item in trails)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs<TrailRTIndex>(item);
				item.UpdateMat();
			}

			foreach (var item in glitches)
			{
				item.Data.isSwap = !item.Data.isSwap;
				CheckRTs<GlitchRTIndex>(item);
				item.UpdateMat();
			}
		}

		//需要在 Pass中调用  不能在feature中
		//因为 pass 是被添加到渲染队列里面 之后执行的
		public void AfterRendering()
		{
			foreach (var item in particles)
			{
				if (!item.Source.Data.isFirst)
				{
					item.Data.isFirst = false;
				}
			}

			foreach (var item in trails)
			{
				if (!item.Source.Data.isFirst)
				{
					item.Data.isFirst = false;
				}
			}

			foreach (var item in glitches)
			{
				if (!item.Source.Data.isFirst)
				{
					item.Data.isFirst = false;
				}
			}

			//不能调整顺序  sources的要放在最后
			foreach (var item in sources)
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

			if (!sources.Contains(obj))
			{
				CheckRTs(obj);
				sources.Add(obj);
			}
		}

		public void Register(SkinnerParticle obj)
		{
			if (obj == null || !obj.CanRender || obj.Data == null)
			{
				return;
			}

			if (!particles.Contains(obj))
			{
				CheckRTs<ParticlesRTIndex>(obj);
				particles.Add(obj);
			}
		}

		public void Register(SkinnerTrail obj)
		{
			if (obj == null || !obj.CanRender || obj.Data == null)
			{
				return;
			}

			if (!trails.Contains(obj))
			{
				CheckRTs<TrailRTIndex>(obj);
				trails.Add(obj);
			}
		}

		public void Register(SkinnerGlitch obj)
		{
			if (obj == null || !obj.CanRender || obj.Data == null)
			{
				return;
			}

			if (!glitches.Contains(obj))
			{
				CheckRTs<GlitchRTIndex>(obj);
				glitches.Add(obj);
			}
		}


		public void Remove(SkinnerSource obj)
		{
			if (sources.Remove(obj))
			{
				DestroyRTs(obj.Data.rts);
				TryDestroy();
			}
		}

		public void Remove(SkinnerParticle obj)
		{
			if (particles.Remove(obj))
			{
				DestroyRTs(obj.Data.rts);
				TryDestroy();
			}
		}

		public void Remove(SkinnerTrail obj)
		{
			if (trails.Remove(obj))
			{
				DestroyRTs(obj.Data.rts);
				TryDestroy();
			}
		}

		public void Remove(SkinnerGlitch obj)
		{
			if (glitches.Remove(obj))
			{
				DestroyRTs(obj.Data.rts);
				TryDestroy();
			}
		}

		private void TryDestroy()
		{
			if (sources.Count > 0 || particles.Count > 0 || trails.Count > 0 || glitches.Count > 0)
			{
				return;
			}

			instance = null;
		}

		private void CheckRTs(SkinnerSource setting)
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

		private void CheckRTs<T>(ISkinnerSetting setting) where T : Enum
		{
			ref RenderTexture[] rts = ref setting.Data.rts;
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
				rts = null;
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

			RenderTextureDescriptor rtd =
				new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGBFloat, 0, 1);

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
		}

		private void DestroyRTs(RenderTexture[] rts)
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