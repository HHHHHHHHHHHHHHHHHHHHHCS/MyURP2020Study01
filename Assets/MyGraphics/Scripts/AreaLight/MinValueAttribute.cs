using UnityEngine;

namespace MyGraphics.Scripts.AreaLight
{
    public class MinValueAttribute : PropertyAttribute
    {
        public float min;

        public MinValueAttribute(float min)
        {
            this.min = min;
        }
    }
}
