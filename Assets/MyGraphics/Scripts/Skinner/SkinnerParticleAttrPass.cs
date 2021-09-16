using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static MyGraphics.Scripts.Skinner.SkinnerShaderConstants;

namespace MyGraphics.Scripts.Skinner
{
	public class SkinnerParticleAttrPass : ScriptableRenderPass
	{
		private const string k_tag = "Skinner Particle Attr";

		private List<SkinnerParticle> particles;
		private Material mat;

		private Vector3 noiseOffset;

		public SkinnerParticleAttrPass()
		{
			profilingSampler = new ProfilingSampler(k_tag);
		}

		public void OnSetup(List<SkinnerParticle> _particles, Material _mat)
		{
			particles = _particles;
			mat = _mat;
		}

		public void OnDestroy()
		{
			particles = null;
			mat = null;
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			CommandBuffer cmd = CommandBufferPool.Get(k_tag);
			using (new ProfilingScope(cmd, profilingSampler))
			{
				foreach (var particle in particles)
				{
					// if (!particle.CanRender)
					// {
					// 	continue;
					// }

					var vertData = particle.Source.Data;

					if (vertData.isFirst)
					{
						continue;
					}

					var data = particle.Data;

					if (data.isFirst)
					{
						noiseOffset = Vector3.zero;
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
						cmd.SetGlobalFloat(RandomSeed_ID, particle.RandomSeed);
					}
					else
					{
						float dt = Time.deltaTime;
						cmd.SetGlobalVector(Damper_ID,
							new Vector4(Mathf.Exp(-particle.Drag * dt), particle.SpeedLimit));
						cmd.SetGlobalVector(Gravity_ID, particle.Gravity * dt);
						cmd.SetGlobalVector(Life_ID,
							new Vector4(dt / particle.MaxLife, dt / (particle.MaxLife * particle.SpeedToLife)));
						var pi360dt = dt * Mathf.Deg2Rad;
						cmd.SetGlobalVector(Spin_ID,
							new Vector4(particle.MaxSpin * pi360dt, particle.SpeedToSpin * pi360dt));
						cmd.SetGlobalVector(NoiseParams_ID,
							new Vector4(particle.NoiseFrequency, particle.NoiseAmplitude * dt));
						
						// Move the noise field backward in the direction of the
						// gravity vector, or simply pull up if no gravity is set.
						var noiseDir = (particle.Gravity == Vector3.zero)
							? Vector3.up
							: particle.Gravity.normalized;
						noiseOffset += noiseDir * particle.NoiseMotion * dt;
						cmd.SetGlobalVector(NoiseOffset_ID, noiseOffset);
						
						
						// Transfer the source position attributes.
						cmd.SetGlobalTexture(SourcePositionTex0_ID, vertData.PrevPosTex);
						cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
					}

					if (particle.UseMRT)
					{
						if (data.isFirst)
						{
							cmd.SetGlobalTexture(SourcePositionTex1_ID, vertData.CurrPosTex);
							cmd.SetGlobalFloat(RandomSeed_ID, particle.RandomSeed);
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								ParticlesKernels.InitializeMRT);
						}
						else
						{
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevTex(ParticlesRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevTex(ParticlesRTIndex.Velocity));
							cmd.SetGlobalTexture(RotationTex_ID, data.PrevTex(ParticlesRTIndex.Rotation));
							CoreUtils.DrawFullScreen(cmd, mat, data.CurrRTIs, data.CurrRTIs[0], null,
								ParticlesKernels.UpdateMRT);
						}
					}
					else
					{
						if (data.isFirst)
						{
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Position), mat,
								ParticlesKernels.InitializePosition);
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Velocity), mat,
								ParticlesKernels.InitializeVelocity);
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Rotation), mat,
								ParticlesKernels.InitializeRotation);
						}
						else
						{
							// Invoke the position update kernel.
							cmd.SetGlobalTexture(PositionTex_ID, data.PrevTex(ParticlesRTIndex.Position));
							cmd.SetGlobalTexture(VelocityTex_ID, data.PrevTex(ParticlesRTIndex.Velocity));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Position), mat,
								ParticlesKernels.UpdatePosition);

							// Invoke the velocity update kernel with the updated positions.
							cmd.SetGlobalTexture(PositionTex_ID, data.CurrTex(ParticlesRTIndex.Position));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Velocity), mat,
								ParticlesKernels.UpdateVelocity);

							// Invoke the rotation update kernel with the updated velocity.
							cmd.SetGlobalTexture(RotationTex_ID, data.PrevTex(ParticlesRTIndex.Rotation));
							cmd.SetGlobalTexture(VelocityTex_ID, data.CurrTex(ParticlesRTIndex.Velocity));
							SkinnerUtils.DrawFullScreen(cmd, data.CurrTex(ParticlesRTIndex.Rotation), mat,
								ParticlesKernels.UpdateRotation);
						}
					}
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}
	}
}