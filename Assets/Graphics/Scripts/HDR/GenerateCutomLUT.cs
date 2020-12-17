using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Graphics.Scripts.HDR
{
    public class GenerateCutomLUT : MonoBehaviour
    {
        public Texture2D inputLUT;
        public ComputeShader generateShader;
        public string outputName = "custom_lut";

        public void Generate()
        {
            if (!inputLUT || !generateShader)
            {
                return;
            }

            Volume volume = gameObject.GetComponent<Volume>();
            if (!volume)
            {
                return;
            }
            

        }
    
    
    }
}
