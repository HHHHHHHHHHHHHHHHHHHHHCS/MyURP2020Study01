using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.ScreenEffect
{
    public class ScreenEffectPass : ScriptableRenderPass
    {
        private ScreenEffectPostProcess settings;
        
        public void Setup(ScreenEffectPostProcess _settings)
        {
            settings = _settings;
        }
        
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            settings = null;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
        }
    }
}
