using System;
using System.Collections.Generic;
using Graphics.Scripts.AtmosphericScattering;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Unity.Mathematics;
using UnityEngine.Assertions.Must;

namespace Graphics.Scripts.TAA
{
	//其实urp也是支持的   只不过要改一下源码	
	//1.首先在DrawSettings中把PerObjectData.Motion打开
	//-------------------------
	//2.接着在 UnityPerFrame 中添加且自己传入
	// float4x4 Matrix_PrevViewProj
	// float4x4 Matrix_ViewJitterProj
	// 接着在UnityPerDraw中添加 下面三个属性
	// float4x4 unity_MatrixPreviousM;
	// float4x4 unity_MatrixPreviousMI;
	// float4 unity_MotionVectorsParams;
	//-------------------------
	//3.TEXCOORD4 储存了上一帧的ObjectPos
	// unity_MotionVectorsParams.x > 0 是 skinMesh
	// unity_MotionVectorsParams.y > 0 强制没有motionVector
	/*
	struct a2v
	{
		float4 vertex: POSITION;
		float3 vertex_old: TEXCOORD4;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f
	{
		float4 vertex: SV_POSITION;
		float4 clipPos: TEXCOORD0;
		float3 clipPos_Old: TEXCOORD1;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	v2f vert(a2v IN)
	{
		v2f o = (v2f) 0;
		UNITY_SETUP_INSTANCE_ID(IN);
		UNITY_TRANSFORM_INSTANCE_ID(IN, o);
		
		float4 worldPos = mul(UNITY_MATRIX_M, float4(IN.vertex.xyz, 1.0));
		
		o.clipPos = TransformWorldToHClip(worldPos.xyz);
		o.clipPos_Old = mul(Matrix_PrevViewProj, mul(unity_MatrixPreviousM, unity_MotionVectorsParams.x > 0?float4(IN.vertex_old.xyz, 1.0): IN.vertex));
		
		o.vertex = mul(Matrix_ViewJitterProj, worldPos);//UNITY_MATRIX_VP
		return o;
	}

	float2 frag(v2f IN): SV_TARGET
	{
		float2 NDC_PixelPos = (IN.clipPos.xy / IN.clipPos.w);
		float2 NDC_PixelPos_Old = (IN.clipPos_Old.xy / IN.clipPos_Old.w);
		float2 ObjectMotion = (NDC_PixelPos - NDC_PixelPos_Old) * 0.5;
		return lerp(ObjectMotion, 0, unity_MotionVectorsParams.y > 0);
	}
	*/

	public enum NeighborMaxSupport
	{
		TileSize10,
		TileSize20,
		TileSize40,
	}

	public class TAAVelocityBufferRenderPass : ScriptableRenderPass
	{
		private const string k_tag = "TAA_VelocityBuffer";

		private const int k_Prepass = 0;
		private const int k_Vertices = 1;
		private const int k_VerticesSkinned = 2;
		private const int k_TileMax = 3;
		private const int k_NeighborMax = 4;

		private const string k_TILESIZE_10 = "TILESIZE_10";
		private const string k_TILESIZE_20 = "TILESIZE_20";
		private const string k_TILESIZE_40 = "TILESIZE_40";

		private static readonly int Corner_ID = Shader.PropertyToID("_Corner");
		private static readonly int CurrV_ID = Shader.PropertyToID("_CurrV");
		private static readonly int CurrVP_ID = Shader.PropertyToID("_CurrVP");
		private static readonly int PreVP_ID = Shader.PropertyToID("_PreVP");

		private static readonly int VelocityTex_ID = Shader.PropertyToID("_VelocityTex");
		private static readonly int VelocityBufferTex_ID = Shader.PropertyToID("_VelocityBufferTex");
		private static readonly int VelocityNeighborMaxTex_ID = Shader.PropertyToID("_VelocityNeighborMaxTex");
		private static readonly int VelocityTileMaxTex_ID = Shader.PropertyToID("_VelocityTileMaxTex");

		private static readonly RenderTargetIdentifier VelocityBufferTex_RTI =
			new RenderTargetIdentifier(VelocityBufferTex_ID);

		private static readonly RenderTargetIdentifier VelocityNeighborMaxTex_RTI =
			new RenderTargetIdentifier(VelocityNeighborMaxTex_ID);

		private static readonly RenderTargetIdentifier VelocityTileMaxTex_RTI =
			new RenderTargetIdentifier(VelocityTileMaxTex_ID);

		public static List<TAAVelocityBufferTag> activeObjects = new List<TAAVelocityBufferTag>(128);


#if UNITY_PS4
		private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGHalf;
#else
		private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGFloat;
#endif

		private Material material;
		private TAAPostProcess settings;
		private Matrix4x4? velocityViewMatrix;
		private RenderTextureDescriptor neighborDesc;

		private static readonly int CurrM_ID = Shader.PropertyToID("_CurrM");
		private static readonly int PrevM_ID = Shader.PropertyToID("_PrevM");


		public TAAVelocityBufferRenderPass(Material mat)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			material = mat;
		}


		public void Setup(TAAPostProcess _settings)
		{
			settings = _settings;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			var desc = cameraTextureDescriptor;
			desc.colorFormat = velocityFormat;
			cmd.GetTemporaryRT(VelocityBufferTex_ID, desc);
			if (settings.neighborMaxGen.value)
			{
				neighborDesc = desc;

				int tileSize = 1;
				switch (settings.neighborMaxSupport.value)
				{
					case NeighborMaxSupport.TileSize10:
						tileSize = 10;
						break;
					case NeighborMaxSupport.TileSize20:
						tileSize = 20;
						break;
					case NeighborMaxSupport.TileSize40:
						tileSize = 40;
						break;
				}

				neighborDesc.width /= tileSize;
				neighborDesc.height /= tileSize;
				neighborDesc.depthBufferBits = 0;
				neighborDesc.memoryless = RenderTextureMemoryless.Depth;
				neighborDesc.msaaSamples = 1;

				cmd.GetTemporaryRT(VelocityNeighborMaxTex_ID, neighborDesc, FilterMode.Bilinear);
			}
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			cmd.ReleaseTemporaryRT(VelocityBufferTex_ID);
			if (settings.neighborMaxGen.value)
			{
				cmd.ReleaseTemporaryRT(VelocityNeighborMaxTex_ID);
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var camera = renderingData.cameraData.camera;

				Matrix4x4 cameraV = camera.worldToCameraMatrix;
				Matrix4x4 cameraP = camera.projectionMatrix;
				Matrix4x4 cameraVP = cameraP * cameraV;

				velocityViewMatrix ??= cameraV;

				CoreUtils.SetRenderTarget(cmd, VelocityBufferTex_RTI, ClearFlag.All, Color.black);

				//0.pre pass
				var jitterSample = settings.activeSample;
				material.SetVector(Corner_ID, camera.GetPerspectiveProjectionCornerRay(jitterSample.x, jitterSample.y));
				material.SetMatrix(CurrV_ID, cameraV);
				material.SetMatrix(CurrVP_ID, cameraVP);
				material.SetMatrix(PreVP_ID, cameraP * velocityViewMatrix.Value);
				CoreUtils.DrawFullScreen(cmd, material, null, k_Prepass);
				velocityViewMatrix = cameraV;

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();

				//1 + 2: vertices + vertices skinned
				foreach (var item in activeObjects)
				{
					material.SetMatrix(CurrM_ID, item.localToWorldCurr);
					material.SetMatrix(PrevM_ID, item.localToWorldPrev);
					int pass = item.useSkinnedMesh ? k_VerticesSkinned : k_Vertices;
					for (int i = 0; i < item.mesh.subMeshCount; i++)
					{
						cmd.DrawMesh(item.mesh, Matrix4x4.identity, material, i, pass);
					}
				}

				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();


				// 3 + 4: tilemax + neighbormax
				if (settings.neighborMaxGen.value)
				{
					CoreUtils.SetKeyword(material, k_TILESIZE_10,
						settings.neighborMaxSupport.value == NeighborMaxSupport.TileSize10);
					CoreUtils.SetKeyword(material, k_TILESIZE_20,
						settings.neighborMaxSupport.value == NeighborMaxSupport.TileSize20);
					CoreUtils.SetKeyword(material, k_TILESIZE_40,
						settings.neighborMaxSupport.value == NeighborMaxSupport.TileSize40);

					cmd.GetTemporaryRT(VelocityTileMaxTex_ID, neighborDesc, FilterMode.Point);

					CoreUtils.SetRenderTarget(cmd, VelocityTileMaxTex_RTI, ClearFlag.None);
					cmd.SetGlobalTexture(VelocityTex_ID, VelocityBufferTex_RTI);
					// cmd.SetGlobalVector("_VelocityTex_TexelSize",
					// 	new Vector4(1f / neighborDesc.width, 1f / neighborDesc.height,
					// 		neighborDesc.width, neighborDesc.height));
					CoreUtils.DrawFullScreen(cmd, material, null, k_TileMax);


					CoreUtils.SetRenderTarget(cmd, VelocityNeighborMaxTex_RTI, ClearFlag.None);
					cmd.SetGlobalTexture(VelocityTex_ID, VelocityTileMaxTex_RTI);
					// cmd.SetGlobalVector("_VelocityTex_TexelSize",
					// 	new Vector4(1f / neighborDesc.width, 1f / neighborDesc.height,
					// 		neighborDesc.width, neighborDesc.height));
					CoreUtils.DrawFullScreen(cmd, material, null, k_NeighborMax);

					cmd.ReleaseTemporaryRT(VelocityTileMaxTex_ID);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();
				}


				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}