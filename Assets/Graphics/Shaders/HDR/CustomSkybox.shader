Shader "MyRP/HDR/CustomSkybox"
{
	Properties
	{
		_Tint ("Tint Color", Color) = (.5, .5, .5, .5)
		[Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
		_Rotation ("Rotation", Range(0, 360)) = 0
		[NoScaleOffset, HDR] _MainTex ("Spherical  (HDR)", 2D) = "grey" { }
	}
	SubShader
	{
		Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
		Cull Off
		ZWrite Off
		
		Pass
		{
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			CBUFFER_START(UnityPerMaterial)
			
			TEXTURE2D_X(_MainTex);
			SAMPLER(sampler_MainTex);
			// float4 _MainTex_TexelSize;
			half4 _MainTex_HDR;
			half4 _Tint;
			half _Exposure;
			float _Rotation;
			
			CBUFFER_END
			
			struct a2v
			{
				float4 vertex: POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 vertex: SV_POSITION;
				float3 texcoord: TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
			};
			
			inline float3 RotateAroundYInDegrees(float3 vertex, float degrees)
			{
				float angle = degrees * PI / 180.0;
				float s, c;
				sincos(angle, s, c);
				float2x2 m = float2x2(c, -s, s, c);
				return float3(mul(m, vertex.xz), vertex.y).xzy;
			}
			
			inline float2 ToRadialCoords(float3 coords)
			{
				float3 normalizedCoords = normalize(coords);
				float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
				float latitude = acos(normalizedCoords.y);
				float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / PI, 1.0 / PI);//[-0.5,0.5]  [0,1]
				return float2(0.5, 1.0) - sphereCoords;//[0,1]
			}
			
			inline half3 DecodeHDR(half4 data, half4 decodeInstructions)
			{
				// 如果decodeInstructions.w为真（alpha值影响RGB通道），请考虑纹理alpha
				half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;
				
				// 如果不支持线性模式，我们可以跳过指数部分
				#if defined(UNITY_COLORSPACE_GAMMA)
					return(decodeInstructions.x * alpha) * data.rgb;
				#else
					#if defined(UNITY_USE_NATIVE_HDR)
						return decodeInstructions.x * data.rgb; // 直接乘法
					#else
						return(decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
					#endif
				#endif
			}
			
			v2f vert(a2v v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				
				float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
				o.vertex = TransformObjectToHClip(rotated);
				o.texcoord = v.vertex.xyz;
				
				return o;
			}
			
			half4 frag(v2f i): SV_TARGET
			{
				float2 uv = ToRadialCoords(i.texcoord.xyz);
				half4 tex = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv);
				half3 c = DecodeHDR(tex, _MainTex_HDR);
				c = c * _Tint.rgb * _Exposure;
				
				return half4(c, 1);
			}
			
			ENDHLSL
			
		}
	}
}
