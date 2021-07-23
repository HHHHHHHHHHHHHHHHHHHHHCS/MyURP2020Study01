using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MyGraphics.Scripts.Other
{
    public class MyBlitFeature : ScriptableRendererFeature
    {
        public RenderPassEvent renderPassEvent;

        public string rtName = "_CameraColorTexture";
        
        private Material myBlitMaterial;
        private MyBlitPass myBlitPass;
        
        public override void Create()
        {
#if UNITY_EDITOR
            if (myBlitMaterial != null)
            {
                DestroyImmediate(myBlitMaterial);
            }
#endif
            myBlitMaterial = CoreUtils.CreateEngineMaterial("MyRP/Other/MyBlit");
            myBlitPass = new MyBlitPass(myBlitMaterial);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            myBlitPass.Setup(rtName);
            myBlitPass.renderPassEvent = renderPassEvent;
            renderer.EnqueuePass(myBlitPass);
        }
    }
}
