using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.Cartoon
{
	public class SSAOPass : ScriptableRenderPass
	{
		private enum ShaderPasses
		{
			AO = 0,
			BlurHorizontal = 1,
			BlurVertical = 2,
			BlurFinal = 3,
		}

		// Constants
		private const string c_SSAOAmbientOcclusionParamName = "_AmbientOcclusionParam";
		private const string c_SSAOTextureName = "_ScreenSpaceOcclusionTexture";

		private const string c_OrthographicCameraKeyword = "_ORTHOGRAPHIC";
		private const string c_NormalReconstructionLowKeyword = "_RECONSTRUCT_NORMAL_LOW";
		private const string c_NormalReconstructionMediumKeyword = "_RECONSTRUCT_NORMAL_MEDIUM";
		private const string c_NormalReconstructionHighKeyword = "_RECONSTRUCT_NORMAL_HIGH";
		private const string c_SourceDepthKeyword = "_SOURCE_DEPTH";

		private const string c_SourceDepthNormalsKeyword = "_SOURCE_DEPTH_NORMALS";
		private const string c_SourceGBufferKeyword = "_SOURCE_GBUFFER"; //用不到

		// Statics
		private static readonly int s_BaseMapID = Shader.PropertyToID("_BaseMap");
		private static readonly int s_ScaleBiasID = Shader.PropertyToID("_ScaleBiasRt");
		private static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");
		private static readonly int s_SSAOTexture1ID = Shader.PropertyToID("_SSAO_OcclusionTexture1");
		private static readonly int s_SSAOTexture2ID = Shader.PropertyToID("_SSAO_OcclusionTexture2");
		private static readonly int s_SSAOTexture3ID = Shader.PropertyToID("_SSAO_OcclusionTexture3");

		public string profilerTag;

		public Material material;

		private SSAOFeature.SSAOSettings currentSettings;

		private ProfilingSampler profilingSampler = new ProfilingSampler("SSAO.Execute()");

		private RenderTextureDescriptor descriptor;

		private RenderTargetIdentifier ssaoTextureTarget1 =
			new RenderTargetIdentifier(s_SSAOTexture1ID, 0, CubemapFace.Unknown, -1);

		private RenderTargetIdentifier ssaoTextureTarget2 =
			new RenderTargetIdentifier(s_SSAOTexture2ID, 0, CubemapFace.Unknown, -1);

		private RenderTargetIdentifier ssaoTextureTarget3 =
			new RenderTargetIdentifier(s_SSAOTexture3ID, 0, CubemapFace.Unknown, -1);


		public bool Setup(SSAOFeature.SSAOSettings settings)
		{
			currentSettings = settings;
			//必须设置  不然needsDepth/needsNormals 会不起作用
			switch (currentSettings.source)
			{
				case SSAOFeature.SSAOSettings.DepthSource.Depth:
					ConfigureInput(ScriptableRenderPassInput.Depth);
					break;
				case SSAOFeature.SSAOSettings.DepthSource.DepthNormals:
					ConfigureInput(ScriptableRenderPassInput.Normal);
					break;
				default:
					throw new ArgumentOutOfRangeException();
			}

			return material != null
			       && currentSettings.intensity > 0.0f
			       && currentSettings.radius > 0.0f
			       && currentSettings.sampleCount > 0;
		}

		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			int downsampleDivider = currentSettings.downsample ? 2 : 1;

			Vector4 ssaoParams = new Vector4(
				currentSettings.intensity,
				currentSettings.radius,
				1.0f / downsampleDivider,
				currentSettings.sampleCount
			);
			material.SetVector(s_SSAOParamsID, ssaoParams);

			CoreUtils.SetKeyword(material, c_OrthographicCameraKeyword, renderingData.cameraData.camera.orthographic);

			if (currentSettings.source == SSAOFeature.SSAOSettings.DepthSource.Depth)
			{
				switch (currentSettings.normalSamples)
				{
					case SSAOFeature.SSAOSettings.NormalQuality.Low:
						CoreUtils.SetKeyword(material, c_NormalReconstructionLowKeyword, true);
						CoreUtils.SetKeyword(material, c_NormalReconstructionMediumKeyword, false);
						CoreUtils.SetKeyword(material, c_NormalReconstructionHighKeyword, false);
						break;
					case SSAOFeature.SSAOSettings.NormalQuality.Medium:
						CoreUtils.SetKeyword(material, c_NormalReconstructionLowKeyword, false);
						CoreUtils.SetKeyword(material, c_NormalReconstructionMediumKeyword, true);
						CoreUtils.SetKeyword(material, c_NormalReconstructionHighKeyword, false);
						break;
					case SSAOFeature.SSAOSettings.NormalQuality.High:
						CoreUtils.SetKeyword(material, c_NormalReconstructionLowKeyword, false);
						CoreUtils.SetKeyword(material, c_NormalReconstructionMediumKeyword, false);
						CoreUtils.SetKeyword(material, c_NormalReconstructionHighKeyword, true);
						break;
					default:
						throw new ArgumentOutOfRangeException();
				}
			}

			switch (currentSettings.source)
			{
				case SSAOFeature.SSAOSettings.DepthSource.DepthNormals:
					CoreUtils.SetKeyword(material, c_SourceDepthKeyword, false);
					CoreUtils.SetKeyword(material, c_SourceDepthNormalsKeyword, true);
					CoreUtils.SetKeyword(material, c_SourceGBufferKeyword, false);
					break;
				default:
					CoreUtils.SetKeyword(material, c_SourceDepthKeyword, true);
					CoreUtils.SetKeyword(material, c_SourceDepthNormalsKeyword, false);
					CoreUtils.SetKeyword(material, c_SourceGBufferKeyword, false);
					break;
			}

			//Get Temp RT
			descriptor = renderingData.cameraData.cameraTargetDescriptor;
			descriptor.msaaSamples = 1;
			descriptor.depthBufferBits = 0;
			descriptor.width /= downsampleDivider;
			descriptor.height /= downsampleDivider;
			descriptor.colorFormat = RenderTextureFormat.ARGB32;
			cmd.GetTemporaryRT(s_SSAOTexture1ID, descriptor, FilterMode.Bilinear);

			descriptor.width *= downsampleDivider;
			descriptor.height *= downsampleDivider;
			cmd.GetTemporaryRT(s_SSAOTexture2ID, descriptor, FilterMode.Bilinear);
			cmd.GetTemporaryRT(s_SSAOTexture3ID, descriptor, FilterMode.Bilinear);

			//configure target and clear color
			//必须要有这个
			//不然的话 没有标记overrideCameraTarget   会clear  colortarget
			ConfigureTarget(ssaoTextureTarget1);
			// ConfigureClear(ClearFlag.None, Color.white);
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (material == null)
			{
				Debug.LogErrorFormat(
					"{0}.Execute(): Missing material. {1} render pass will not execute. Check for missing reference in the renderer resources.",
					GetType().Name, profilerTag);
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get();
			using (new ProfilingScope(cmd, profilingSampler))
			{
				//lit shader 中 enable _SCREEN_SPACE_OCCLUSION
				CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, true);

				// scaleBias.x = flipSign
				// scaleBias.y = scale
				// scaleBias.z = bias
				// scaleBias.w = unused
				float flipSign = (renderingData.cameraData.IsCameraProjectionMatrixFlipped()) ? -1.0f : 1.0f;
				Vector4 scaleBias = (flipSign < 0.0f)
					? new Vector4(flipSign, 1.0f, -1.0f, 1.0f)
					: new Vector4(flipSign, 0.0f, 1.0f, 1.0f);
				cmd.SetGlobalVector(s_ScaleBiasID, scaleBias);

				Render(cmd, ssaoTextureTarget1, ShaderPasses.AO);
				RenderAndSetBaseMap(cmd, ssaoTextureTarget1, ssaoTextureTarget2, ShaderPasses.BlurHorizontal);
				RenderAndSetBaseMap(cmd, ssaoTextureTarget2, ssaoTextureTarget3, ShaderPasses.BlurVertical);
				RenderAndSetBaseMap(cmd, ssaoTextureTarget3, ssaoTextureTarget2, ShaderPasses.BlurFinal);


				// Set the global SSAO texture and AO Params
				cmd.SetGlobalTexture(c_SSAOTextureName, ssaoTextureTarget2);
				cmd.SetGlobalVector(c_SSAOAmbientOcclusionParamName,
					new Vector4(0f, 0f, 0f, currentSettings.directLightStrength));
				
				//SSAORT1 2 3  因为用的是RenderTargetIdentifier  所以不用setGlobalTexture  也可以直接在shader中获取
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		private void Render(CommandBuffer cmd, RenderTargetIdentifier target, ShaderPasses pass)
		{
			cmd.SetRenderTarget(target,
				RenderBufferLoadAction.DontCare,
				RenderBufferStoreAction.Store,
				target,
				RenderBufferLoadAction.DontCare,
				RenderBufferStoreAction.DontCare
			);

			//四边形
			cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, material, 0, (int) pass);
		}

		private void RenderAndSetBaseMap(CommandBuffer cmd, RenderTargetIdentifier baseMap,
			RenderTargetIdentifier target, ShaderPasses pass)
		{
			cmd.SetGlobalTexture(s_BaseMapID, baseMap);
			Render(cmd, target, pass);
		}

		public override void OnCameraCleanup(CommandBuffer cmd)
		{
			if (cmd == null)
			{
				throw new ArgumentNullException("cmd");
			}

			CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.ScreenSpaceOcclusion, false);
			cmd.ReleaseTemporaryRT(s_SSAOTexture1ID);
			cmd.ReleaseTemporaryRT(s_SSAOTexture2ID);
			cmd.ReleaseTemporaryRT(s_SSAOTexture3ID);
		}
	}
}