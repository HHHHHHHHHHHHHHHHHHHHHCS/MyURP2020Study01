using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Unity.Mathematics;

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

		public static List<TAAVelocityBufferTag> activeObjects = new List<TAAVelocityBufferTag>(128);


// #if UNITY_PS4
// 		private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGHalf;
// #else
		private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGFloat;
// #endif

		private Material velocityMaterial;
		private TAAPostProcess settings;


		public TAAVelocityBufferRenderPass(Material mat)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			velocityMaterial = mat;
		}


		public void Setup(TAAPostProcess _settings)
		{
			settings = _settings;
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
		{
			var desc = cameraTextureDescriptor;
			//TODO:need depth
			// cmd.GetTemporaryRT("velocityBuffer",desc.width,desc.height,,);
		}


		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				//可以用mpb 也可以直接material.set
				context.ExecuteCommandBuffer(cmd);
				cmd.Clear();
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}