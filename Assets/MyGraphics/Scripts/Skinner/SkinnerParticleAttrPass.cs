using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

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

		private SkinnerFeature skinnerFeature;
		private SkinnerParticle particle;
		private Material mat;

		private RenderTexture positionTex0;
		private RenderTexture positionTex1;
		private RenderTexture velocityTex0;
		private RenderTexture velocityTex1;
		private RenderTexture rotationTex0;
		private RenderTexture rotationTex1;

		private RenderTargetIdentifier[] prevRTIs, currRTIs;

		private bool isFirst;
		private Vector3 noiseOffset;

		public SkinnerParticleAttrPass(SkinnerFeature _skinnerFeature)
		{
			profilingSampler = new ProfilingSampler(k_tag);
			skinnerFeature = _skinnerFeature;
		}

		public void OnSetup(SkinnerParticle _particle, Material _mat)
		{
			particle = _particle;
			mat = _mat;
			OnCreate();
		}

		public void OnCreate()
		{
			int w = particle.Template.InstanceCount;
			int h = 1;

			if (particle.Reconfigured || positionTex0 == null
			                          || positionTex0.width != w
			                          || positionTex0.height != 1)
			{
				particle.Reconfigured = false;
				isFirst = true;

				SkinnerUtils.CreateRT(ref positionTex0, w, h, "Particle_" + nameof(positionTex0));
				SkinnerUtils.CreateRT(ref positionTex1, w, h, "Particle_" + nameof(positionTex1));
				SkinnerUtils.CreateRT(ref velocityTex0, w, h, "Particle_" + nameof(velocityTex0));
				SkinnerUtils.CreateRT(ref velocityTex1, w, h, "Particle_" + nameof(velocityTex1));
				SkinnerUtils.CreateRT(ref rotationTex0, w, h, "Particle_" + nameof(rotationTex0));
				SkinnerUtils.CreateRT(ref rotationTex1, w, h, "Particle_" + nameof(rotationTex1));

				prevRTIs = new RenderTargetIdentifier[3]
				{
					positionTex1,
					velocityTex1,
					rotationTex1,
				};
				currRTIs = new RenderTargetIdentifier[3]
				{
					positionTex0,
					velocityTex0,
					rotationTex0,
				};
			}
		}

		public void OnDestroy()
		{
			SkinnerUtils.CleanRT(ref positionTex0);
			SkinnerUtils.CleanRT(ref positionTex1);
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
				CoreUtils.Swap(ref prevRTIs, ref currRTIs);

				if (isFirst)
				{
					isFirst = false;
					noiseOffset = Vector3.zero;
					mat.SetTexture(SourcePositionTex1_ID,
						skinnerFeature.VertexAttrPass.CurrPosTex);
					mat.SetFloat(RandomSeed_ID, particle.RandomSeed);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Position], mat,
						ShaderKernels.InitializePosition);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Velocity], mat,
						ShaderKernels.InitializeVelocity);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Rotation], mat,
						ShaderKernels.InitializeRotation);
				}
				else
				{
					float dt = Time.deltaTime;
					mat.SetVector(Damper_ID,
						new Vector4(Mathf.Exp(-particle.Drag * dt), particle.SpeedLimit));
					mat.SetVector(Gravity_ID, particle.Gravity * dt);
					mat.SetVector(Life_ID,
						new Vector4(dt / particle.MaxLife, dt / (particle.MaxLife * particle.SpeedToLife)));
					var pi360dt = dt * Mathf.Deg2Rad;
					mat.SetVector(Spin_ID, new Vector4(particle.MaxSpin * pi360dt, particle.SpeedToSpin * pi360dt));
					mat.SetVector(NoiseParams_ID, new Vector4(particle.NoiseFrequency, particle.NoiseAmplitude * dt));


					// Move the noise field backward in the direction of the
					// gravity vector, or simply pull up if no gravity is set.
					var noiseDir = (particle.Gravity == Vector3.zero) ? Vector3.up : particle.Gravity.normalized;
					noiseOffset += noiseDir * particle.NoiseMotion * dt;
					mat.SetVector(NoiseOffset_ID, noiseOffset);

					// Transfer the source position attributes.
					cmd.SetGlobalTexture(SourcePositionTex0_ID, skinnerFeature.VertexAttrPass.PrevPosTex);
					cmd.SetGlobalTexture(SourcePositionTex1_ID, skinnerFeature.VertexAttrPass.CurrPosTex);

					// Invoke the position update kernel.
					cmd.SetGlobalTexture(PositionTex_ID, prevRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(VelocityTex_ID, prevRTIs[RTIndexs.Velocity]);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Position], mat, ShaderKernels.UpdatePosition);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();


					// Invoke the velocity update kernel with the updated positions.
					cmd.SetGlobalTexture(PositionTex_ID, currRTIs[RTIndexs.Position]);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Velocity], mat, ShaderKernels.UpdateVelocity);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();

					// Invoke the rotation update kernel with the updated velocity.
					cmd.SetGlobalTexture(RotationTex_ID, prevRTIs[RTIndexs.Rotation]);
					cmd.SetGlobalTexture(VelocityTex_ID, currRTIs[RTIndexs.Velocity]);
					SkinnerUtils.DrawFullScreen(cmd, currRTIs[RTIndexs.Rotation], mat, ShaderKernels.UpdateRotation);

					context.ExecuteCommandBuffer(cmd);
					cmd.Clear();

					cmd.SetGlobalTexture(ParticlePositionTex_ID, currRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(ParticleVelocityTex_ID, currRTIs[RTIndexs.Velocity]);
					cmd.SetGlobalTexture(ParticleRotationTex_ID, currRTIs[RTIndexs.Rotation]);
					cmd.SetGlobalTexture(ParticlePrevPositionTex_ID, prevRTIs[RTIndexs.Position]);
					cmd.SetGlobalTexture(ParticlePrevRotationTex_ID, prevRTIs[RTIndexs.Rotation]);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}