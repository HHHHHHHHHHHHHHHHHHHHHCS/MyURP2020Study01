using System;
using System.Net.NetworkInformation;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.Skinner
{
	public static class SkinnerShaderConstants
	{
		public static int SrcTex_ID = Shader.PropertyToID("_SrcTex");
		public static int SourcePositionTex0_ID = Shader.PropertyToID("_SourcePositionTex0");
		public static int SourcePositionTex1_ID = Shader.PropertyToID("_SourcePositionTex1");
		public static int PositionTex_ID = Shader.PropertyToID("_PositionTex");
		public static int VelocityTex_ID = Shader.PropertyToID("_VelocityTex");
		public static int RotationTex_ID = Shader.PropertyToID("_RotationTex");
		public static int OrthnormTex_ID = Shader.PropertyToID("_OrthnormTex");

		public static int ParticlePositionTex_ID = Shader.PropertyToID("_ParticlePositionTex");
		public static int ParticleVelocityTex_ID = Shader.PropertyToID("_ParticleVelocityTex");
		public static int ParticleRotationTex_ID = Shader.PropertyToID("_ParticleRotationTex");
		public static int ParticlePrevPositionTex_ID = Shader.PropertyToID("_ParticlePrevPositionTex");
		public static int ParticlePrevRotationTex_ID = Shader.PropertyToID("_ParticlePrevRotationTex");

		public static int TrailPositionTex_ID = Shader.PropertyToID("_TrailPositionTex");
		public static int TrailVelocityTex_ID = Shader.PropertyToID("_TrailVelocityTex");
		public static int TrailOrthnormTex_ID = Shader.PropertyToID("_TrailOrthnormTex");
		public static int TrailPrevPositionTex_ID = Shader.PropertyToID("_TrailPrevPositionTex");
		public static int TrailPrevVelocityTex_ID = Shader.PropertyToID("_TrailPrevVelocityTex");
		public static int TrailPrevOrthnormTex_ID = Shader.PropertyToID("_TrailPrevOrthnormTex");

		public static int RandomSeed_ID = Shader.PropertyToID("_RandomSeed");
		public static int Damper_ID = Shader.PropertyToID("_Damper");
		public static int Gravity_ID = Shader.PropertyToID("_Gravity");
		public static int Life_ID = Shader.PropertyToID("_Life");
		public static int Spin_ID = Shader.PropertyToID("_Spin");
		public static int NoiseParams_ID = Shader.PropertyToID("_NoiseParams");
		public static int NoiseOffset_ID = Shader.PropertyToID("_NoiseOffset");
		public static int Scale_ID = Shader.PropertyToID("_Scale");
		public static int SpeedLimit_ID = Shader.PropertyToID("_SpeedLimit");
		public static int Drag_ID = Shader.PropertyToID("_Drag");
		public static int LineWidth_ID = Shader.PropertyToID("_LineWidth");
	}

	public class SkinnerVertexData
	{
		public SkinnedMeshRenderer smr;
		public bool isFirst = true;
		public Material mat;
		public RenderTexture[] rts;

		public bool isSwap = false;

		private RenderTargetIdentifier[] rts0, rts1;

		public RenderTexture CurrPosTex => isSwap ? rts[VertexRTIndex.Position0] : rts[VertexRTIndex.Position1];
		public RenderTexture PrevPosTex => isSwap ? rts[VertexRTIndex.Position1] : rts[VertexRTIndex.Position0];
		public RenderTexture NormalTex => rts[VertexRTIndex.Normal];
		public RenderTexture TangentTex => rts[VertexRTIndex.Tangent];

		public RenderTargetIdentifier[] CurrRTS
		{
			get
			{
				if (isSwap)
				{
					if (rts0 == null)
					{
						rts0 = new RenderTargetIdentifier[3];
						rts0[0] = rts[VertexRTIndex.Position0];
						rts0[1] = rts[VertexRTIndex.Normal];
						rts0[2] = rts[VertexRTIndex.Tangent];
					}

					return rts0;
				}
				else
				{
					if (rts1 == null)
					{
						rts1 = new RenderTargetIdentifier[3];
						rts1[0] = rts[VertexRTIndex.Position1];
						rts1[1] = rts[VertexRTIndex.Normal];
						rts1[2] = rts[VertexRTIndex.Tangent];
					}

					return rts1;
				}
			}
		}


		public SkinnerVertexData(SkinnedMeshRenderer _smr, Material _mat)
		{
			smr = _smr;
			mat = _mat;
		}
	}

	public class SkinnerData
	{
		public Material mat;
		public bool isFirst = true;
		public bool isSwap = false;
		public RenderTexture[] rts;

		public int CurrIndex => isSwap ? 0 : rts.Length / 2;
		public int PrevIndex => isSwap ? rts.Length / 2 : 0;

		//enum hash code  就是原值
		//https://blog.csdn.net/lzdidiv/article/details/71170528
		public RenderTexture CurrTex(Enum index) => rts[CurrIndex + index.GetHashCode()];
		public RenderTexture PrevTex(Enum index) => rts[PrevIndex + index.GetHashCode()];
	}

	public class VertexRTIndex
	{
		public const int Position0 = 0;
		public const int Position1 = 1;
		public const int Normal = 2;
		public const int Tangent = 3;
	}

	public class ParticlesKernels
	{
		public const int InitializePosition = 0;
		public const int InitializeVelocity = 1;
		public const int InitializeRotation = 2;
		public const int UpdatePosition = 3;
		public const int UpdateVelocity = 4;
		public const int UpdateRotation = 5;
	}

	public enum ParticlesRTIndex
	{
		Position = 0,
		Velocity = 1,
		Rotation = 2,
	}

	public class TrailKernels
	{
		public const int InitializePosition = 0;
		public const int InitializeVelocity = 1;
		public const int InitializeOrthnorm = 2;
		public const int UpdatePosition = 3;
		public const int UpdateVelocity = 4;
		public const int UpdateOrthnorm = 5;
	}

	public enum TrailRTIndex
	{
		Position = 0,
		Velocity = 1,
		Orthnorm = 2,
	}
	
	public class GlitchKernels
	{
		public const int InitializePosition = 0;
		public const int InitializeVelocity = 1;
		public const int UpdatePosition = 2;
		public const int UpdateVelocity = 3;
	}

	public enum GlitchRTIndex
	{
		Position = 0,
		Velocity = 1,
	}
}