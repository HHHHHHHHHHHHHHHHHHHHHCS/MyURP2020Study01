using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.XPostProcessing
{
    public class XPostProcessingFeature : ScriptableRendererFeature
    {
        public override void Create()
        {

        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // PostProcessingHelper.SetupTempRT();
        }
    }
}
