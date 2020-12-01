Shader "MyRP/CartoonWater/GradientSkybox"
{
	Properties
	{
		_Tiling ("Tiling", Vector) = (5, 5, 0, 0)
		_Density ("Density", Range(0, 1)) = 0.25
		_Size ("Size", Range(0.1, 1)) = 0.5
		_Thickness ("Thickness", Range(0.025, 0.25)) = 0.1
		_StarColor ("Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Tags { /*"RenderPipeline" = "UniversalPipeline"*/ "RenderType" = "Opaque" "Queue" = "Geometry" }
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite On
		
		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			
			HLSLPROGRAM
			
			//#pragma target 4.5
			//#pragma exclude_renderers d3d11_9x gles
			#pragma vertex vert
			#pragma fragment frag
			
			// Keywords
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ DOTS_INSTANCING_ON
			
			// Keywords
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma shader_feature _ _SAMPLE_GI
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			
			struct a2v
			{
				float4 vertex: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 positionCS: SV_POSITION;
				float3 positionWS: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			CBUFFER_START(UnityPerMaterial)
			float2 _Tiling;
			float _Density;
			float _Size;
			float _Thickness;
			float4 _StarColor;
			CBUFFER_END
			
			float RandomRange(float2 seed, float minVal, float maxVal)
			{
				float rd = frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
				return lerp(minVal, maxVal, rd);
			}
			
			float Ellipse(float2 uv, float width, float height)
			{
				float d = length((uv * 2 - 1) / float2(width, height));
				return saturate((1 - d) / fwidth(d));
			}
			
			//球转换成UV
			float2 SphericalUV(float3 worldPosition)
			{
				float3 dir = normalize(worldPosition);
				float2 uv;
				uv.x = atan2(dir.x, dir.z) / TWO_PI;
				uv.y = asin(dir.y) / HALF_PI;
				return uv;
			}
			
			float RandomByTileUV(float2 uv)
			{
				uv = uv * _Tiling;
				float2 fracUV = frac(uv);
				float2 floorUV = floor(uv);
				float size = RandomRange(floorUV * float2(314, 314), 0.1, 0.75);
				float ret = Ellipse(fracUV, size, size);
				ret *= step(1 - _Density, RandomRange(floorUV, 0, 1));
				return ret;
			}
			
			float4 SkyColor(float val)
			{
				val = 1 - val;
				//TODO:
			}
			
			float4 StarColor(float val)
			{
				return _StarColor * val;
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				
				o.positionWS = TransformObjectToWorld(v.vertex.xyz);
				o.positionCS = TransformWorldToHClip(o.positionWS);
				
				return o;
			}
			
			float4 frag(v2f i): SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				
				return 0;
			}
			
			ENDHLSL
			
		}
	}
}
