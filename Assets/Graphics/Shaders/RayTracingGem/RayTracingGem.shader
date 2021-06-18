//https://github.com/Sorumi/UnityRayTracingGem
Shader "MyRP/RayTracingGem/RayTracingGem"
{
	Properties
	{
		_TraceCount("Trace Count", Int) = 5
		_IOR("IOR", Range(1,5)) = 2.417

		_Color("Color", Color) = (1, 1, 1, 1)
		_AbsorbIntensity("Absorb Intensity", Range(0,10)) = 1.0
		_ColorMultiply("Color Multiply", Range(0,5)) = 1.0
		_ColorAdd("Color Add", Range(0,1)) = 0.0

		_Specular("Specular", Range(0,1)) = 0.0
	}
	SubShader
	{

		Pass
		{
			//Cull Back

			HLSLPROGRAM

			#pragma enable_d3d11_debug_symbols
			
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#include "RayTracingGem.hlsl"


			struct a2v
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 screenPos : TEXCOORD0;
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.vertex = TransformObjectToHClip(v.vertex.xyz);
				o.screenPos = o.vertex.xy / o.vertex.w;
				// o.screenPos.y *= _ProjectionParams.x;
				return o;
			}

			half4 frag(v2f IN/*, half facing : VFACE*/) : SV_Target
			{
				half3 result = RayTrace(IN.screenPos);

				return half4(result, 1);
			}
			ENDHLSL
		}
	}
}