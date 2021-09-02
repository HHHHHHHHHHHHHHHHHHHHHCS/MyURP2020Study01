using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerParticleAttrPass : ScriptableRenderPass
	{
		private class ShaderKernels
		{
			public const int InitializePosition = 0;
			public const int InitializeVelocity = 1;
			public const int InitializeRotation = 2;
			public const int UpdatePosition = 3;
			public const int UpdateVelocity = 4;
			public const int UpdateRotation = 5;
		}

		private class RTIndexs
		{
			public const int Position = 0;
			public const int Velocity = 1;
			public const int Rotation = 2;
		}

		private const string k_tag = "Skinner Particle Attr";

		private SkinnerParticleTemplate template;
		private Material mat;

		private RenderTexture skinnerPositionTex0;
		private RenderTexture skinnerPositionTex1;
		private RenderTexture velocityTex0;
		private RenderTexture velocityTex1;
		private RenderTexture rotationTex0;
		private RenderTexture rotationTex1;

		private RenderTargetIdentifier[] lastRTIs, currRTIs;

		private bool isFirst;
		private bool pingpong;

		public SkinnerParticleAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void OnSetup(SkinnerParticleTemplate _template, Material _mat)
		{
			template = _template;
			mat = _mat;

			OnCreate();

			if (pingpong)
			{
				CoreUtils.Swap(ref lastRTIs, ref currRTIs);
			}
			else
			{
				CoreUtils.Swap(ref lastRTIs, ref currRTIs);
			}


			pingpong = !pingpong;
		}

		public void OnCreate()
		{
			if (skinnerPositionTex0 == null || skinnerPositionTex0.width != template.InstanceCount)
			{
				isFirst = true;
				pingpong = true;

				int w = template.InstanceCount;
				int h = 1;

				SkinnerUtils.CreateRT(ref skinnerPositionTex0, w, h, nameof(skinnerPositionTex0));
				SkinnerUtils.CreateRT(ref skinnerPositionTex1, w, h, nameof(skinnerPositionTex1));
				SkinnerUtils.CreateRT(ref velocityTex0, w, h, nameof(velocityTex0));
				SkinnerUtils.CreateRT(ref velocityTex1, w, h, nameof(velocityTex1));
				SkinnerUtils.CreateRT(ref rotationTex0, w, h, nameof(rotationTex0));
				SkinnerUtils.CreateRT(ref rotationTex1, w, h, nameof(rotationTex1));

				lastRTIs = new RenderTargetIdentifier[3]
				{
					skinnerPositionTex1,
					velocityTex1,
					rotationTex1,
				};
				currRTIs = new RenderTargetIdentifier[3]
				{
					skinnerPositionTex0,
					velocityTex0,
					rotationTex0,
				};
			}
		}

		public void OnDestroy()
		{
			SkinnerUtils.CleanRT(ref skinnerPositionTex0);
			SkinnerUtils.CleanRT(ref skinnerPositionTex1);
			SkinnerUtils.CleanRT(ref velocityTex0);
			SkinnerUtils.CleanRT(ref velocityTex1);
			SkinnerUtils.CleanRT(ref rotationTex0);
			SkinnerUtils.CleanRT(ref rotationTex1);
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				if (isFirst)
				{
					isFirst = false;
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Position], mat,
						ShaderKernels.InitializePosition);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Velocity], mat,
						ShaderKernels.InitializeVelocity);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Rotation], mat,
						ShaderKernels.InitializeRotation);
				}
				else
				{
					//todo:
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}