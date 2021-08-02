#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN
//mac上支持将同一张贴图的不同mips同时作为输入输出。
//但是在win平台上不支持，因此需要使用两张RT进行PingPong模式来生成
//其他平台暂未确认
#define PING_PONG_COPY
#endif

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.GPUDrivenTerrain
{
	public class HizMapRenderPass : ScriptableRenderPass
	{
		private class ShaderConstants
		{
			public const string k_REVERSE_Z = "_REVERSE_Z";
			public const string k_PING_PONG_COPY = "_PING_PONG_COPY";

			public static readonly int HizCameraMatrixVP_ID = Shader.PropertyToID("_HizCameraMatrixVP");
			public static readonly int HizCameraPosition_ID = Shader.PropertyToID("_HizCameraPositionWS");
			public static readonly int InTex_ID = Shader.PropertyToID("_InTex");
			public static readonly int MipTex_ID = Shader.PropertyToID("_MipTex");
			public static readonly int MipCopyTex_ID = Shader.PropertyToID("_MipCopyTex");
			public static readonly int PingTex_ID = Shader.PropertyToID("_PingTex");
			public static readonly int PongTex_ID = Shader.PropertyToID("_PongTex");

			public static readonly int SrcTexSize_ID = Shader.PropertyToID("_SrcTexSize");
			public static readonly int DstTexSize_ID = Shader.PropertyToID("_DstTexSize");
			public static readonly int Mip_ID = Shader.PropertyToID("_Mip");
			public static readonly int HizMap_ID = Shader.PropertyToID("_HizMap");
			public static readonly int HizMapSize_ID = Shader.PropertyToID("_HizMapSize");

			public static readonly RenderTargetIdentifier CameraDepthTexture_RTI = "_CameraDepthTexture";
		}

		private const string k_tag = "HiZ";

		private const int KERNEL_BLIT = 0;
		private const int KERNEL_REDUCE = 1;

		private ComputeShader computeShader;
		private RenderTexture hizmap;

		public static RenderTexture HiZMap ;

		public HizMapRenderPass(ComputeShader cs)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			computeShader = cs;
			CoreUtils.SetKeyword(cs, ShaderConstants.k_REVERSE_Z, SystemInfo.usesReversedZBuffer);
#if PING_PONG_COPY
			bool pingPongCopy = true;
#else
			bool pingPongCopy = false;
#endif
			CoreUtils.SetKeyword(cs, ShaderConstants.k_PING_PONG_COPY, pingPongCopy);
		}


		private RenderTexture GetTempHizMapTexture(int size, int mipCount)
		{
			var desc = new RenderTextureDescriptor(size, size, RenderTextureFormat.RFloat, 0, mipCount);
			var rt = new RenderTexture(desc)
			{
				autoGenerateMips = false,
				useMipMap = mipCount > 1,
				filterMode = FilterMode.Point,
				enableRandomWrite = true
			};
			rt.Create();
			return rt;
		}

		public static int GetHiZMapSize(Camera camera)
		{
			var screenSize = Mathf.Max(camera.pixelWidth, camera.pixelHeight);
			var textureSize = Mathf.NextPowerOfTwo(screenSize);
			return textureSize;
		}

		private RenderTexture EnsureHizMap(Camera camera)
		{
			var preferMapSize = GetHiZMapSize(camera);
			if (hizmap && hizmap.width == preferMapSize && hizmap.height == preferMapSize)
			{
				return hizmap;
			}

			if (hizmap)
			{
				CoreUtils.Destroy(hizmap);
			}

			var mipCount = (int) Mathf.Log(preferMapSize, 2) + 1;
			hizmap = GetTempHizMapTexture(preferMapSize, mipCount);
			HiZMap = hizmap;
			return hizmap;
		}

		private void GetTempHizMapTexture(int nameId, int size, CommandBuffer cmd)
		{
			var desc = new RenderTextureDescriptor(size, size, RenderTextureFormat.RFloat, 0, 1)
			{
				autoGenerateMips = false,
				useMipMap = false,
				enableRandomWrite = true
			};
			cmd.GetTemporaryRT(nameId, desc, FilterMode.Point);
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get();
			using (new ProfilingScope(cmd, profilingSampler))
			{
				var camera = renderingData.cameraData.camera;
				var hizMap = this.EnsureHizMap(camera);

				var dstWidth = hizMap.width;
				var dstHeight = hizMap.height;
				uint threadX, threadY, threadZ;
				computeShader.GetKernelThreadGroupSizes(KERNEL_BLIT, out threadX, out threadY, out threadZ);

				//blit
				//-----------------------
				cmd.SetComputeTextureParam(computeShader, KERNEL_BLIT, ShaderConstants.InTex_ID,
					ShaderConstants.CameraDepthTexture_RTI);
				cmd.SetComputeTextureParam(computeShader, KERNEL_BLIT, ShaderConstants.MipTex_ID, hizMap, 0);

				cmd.SetComputeVectorParam(computeShader, ShaderConstants.SrcTexSize_ID,
					new Vector4(camera.pixelWidth, camera.pixelHeight, 0, 0));
				cmd.SetComputeVectorParam(computeShader, ShaderConstants.DstTexSize_ID,
					new Vector4(dstWidth, dstHeight, 0, 0));


				//虽然也可以用cmd.GenerateMips 自动生成   但是不准确  所以我们自己生成 
#if PING_PONG_COPY
				GetTempHizMapTexture(ShaderConstants.PingTex_ID, hizMap.width, cmd);
				cmd.SetComputeTextureParam(computeShader, KERNEL_BLIT, ShaderConstants.MipCopyTex_ID,
					ShaderConstants.PingTex_ID, 0);
#endif
				var groupX = Mathf.CeilToInt(dstWidth * 1.0f / threadX);
				var groupY = Mathf.CeilToInt(dstHeight * 1.0f / threadY);
				cmd.DispatchCompute(computeShader, KERNEL_BLIT, groupX, groupY, 1);

				//mipmap
				//---------------------------

				computeShader.GetKernelThreadGroupSizes(KERNEL_REDUCE, out threadX, out threadY, out threadZ);
#if PING_PONG_COPY
				cmd.SetComputeTextureParam(computeShader, KERNEL_REDUCE, ShaderConstants.InTex_ID,
					ShaderConstants.PingTex_ID);
#else
				cmd.SetComputeTextureParam(computeShader,KERNEL_REDUCE,ShaderConstants.InTex_ID,hizMap);
#endif

				int pingTex = ShaderConstants.PingTex_ID;
				int pongTex = ShaderConstants.PongTex_ID;
				for (var i = 1; i < hizMap.mipmapCount; i++)
				{
					dstWidth = Mathf.CeilToInt(dstWidth / 2.0f);
					dstHeight = Mathf.CeilToInt(dstHeight / 2.0f);
					cmd.SetComputeVectorParam(computeShader, ShaderConstants.DstTexSize_ID,
						new Vector4(dstWidth, dstHeight, 0, 0));
					cmd.SetComputeIntParam(computeShader, ShaderConstants.Mip_ID, i);
					cmd.SetComputeTextureParam(computeShader, KERNEL_REDUCE, ShaderConstants.MipTex_ID, hizmap, i);
#if PING_PONG_COPY
					GetTempHizMapTexture(pongTex, dstWidth, cmd);
					cmd.SetComputeTextureParam(computeShader, KERNEL_REDUCE, ShaderConstants.MipCopyTex_ID, pongTex, 0);
#endif

					groupX = Mathf.CeilToInt(dstWidth / (float) threadX);
					groupY = Mathf.CeilToInt(dstHeight / (float) threadY);
					cmd.DispatchCompute(computeShader, KERNEL_REDUCE, groupX, groupY, 1);

#if PING_PONG_COPY
					cmd.ReleaseTemporaryRT(pingTex);
					cmd.SetComputeTextureParam(computeShader, KERNEL_REDUCE, ShaderConstants.InTex_ID, pongTex);
					CoreUtils.Swap(ref pingTex, ref pongTex);
#endif
				}

#if PING_PONG_COPY
				cmd.ReleaseTemporaryRT(pingTex);
#endif

				cmd.SetGlobalTexture(ShaderConstants.HizMap_ID, hizMap);
				var matrixVP = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix;
				cmd.SetGlobalMatrix(ShaderConstants.HizCameraMatrixVP_ID, matrixVP);
				cmd.SetGlobalVector(ShaderConstants.HizMapSize_ID,
					new Vector4(hizMap.width, hizMap.height, hizMap.mipmapCount));
				cmd.SetGlobalVector(ShaderConstants.HizCameraPosition_ID, camera.transform.position);
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}