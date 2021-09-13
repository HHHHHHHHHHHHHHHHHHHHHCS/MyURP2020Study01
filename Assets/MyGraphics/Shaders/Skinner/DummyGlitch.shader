Shader "MyRP/Skinner/DummyGlitch"
{
	Properties
	{
		_Albedo("Albedo", Color) = (1, 1, 1, 1)

		[Space]
		[HDR] _Emission("Emission", Color) = (1, 1, 1)

		[Space]
		_Voxelize("Voxelize", Float) = 0.2
		_Cutoff("Cutoff", Range(0, 1)) = 0.1
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "Queue" = "AlphaTest" /*"RenderPipeline" = "UniversalRenderPipeline"*/
		}
		LOD 100

		Pass
		{
			Name "ForwardLit"
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


			half4 _Albedo;
			half4 _Emission;
			float _Voxelize;
			half _Cutoff;

			struct a2v
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
			};

			float UVRandom(float2 uv, float salt)
			{
				uv += float2(salt, 0);
				return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
			}

			v2f vert(a2v IN)
			{
				v2f o;
				IN.vertex.xyz = floor(IN.vertex.xyz / _Voxelize) * _Voxelize;
				o.worldPos = TransformObjectToWorld(IN.vertex.xyz);
				o.pos = TransformWorldToHClip(o.worldPos);
				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				float3 vp = floor(IN.worldPos.xyz / _Voxelize) * _Voxelize;
				float rnd = UVRandom(vp.xy, vp.z + floor(_Time.y * 5));

				clip(_Cutoff - rnd);

				return _Albedo + _Emission;
			}
			ENDHLSL
		}
	}
}