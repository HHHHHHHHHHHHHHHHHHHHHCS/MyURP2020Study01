///  Reference: 	Anjyo K, Hiramitsu K. Stylized highlights for cartoon rendering and animation[J]. 
///						Computer Graphics and Applications, IEEE, 2003, 23(4): 54-61.

//本来卡通还有outline 阴影什么的  这里偷懒就做一个高光
//By https://github.com/candycat1992/NPR_Lab
Shader "MyRP/CartoonStylizedHighlights/CartoonStylizedHighlights"
{
	Properties
	{
		_Color ("Diffuse Color", Color) = (1, 1, 1, 1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {}
		_Outline ("Outline", Range(0,1)) = 0.1
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SpecularScale ("Specular Scale", Range(0, 0.05)) = 0.01
		_TranslationX ("Translation X", Range(-1, 1)) = 0
		_TranslationY ("Translation Y", Range(-1, 1)) = 0
		_RotationX ("Rotation X", Range(-180, 180)) = 0
		_RotationY ("Rotation Y", Range(-180, 180)) = 0
		_RotationZ ("Rotation Z", Range(-180, 180)) = 0
		_ScaleX ("Scale X", Range(-1, 1)) = 0
		_ScaleY ("Scale Y", Range(-1, 1)) = 0
		_SplitX ("Split X", Range(0, 1)) = 0
		_SplitY ("Split Y", Range(0, 1)) = 0
		_SquareN ("Square N", Range(1, 10)) = 1
		_SquareScale ("Square Scale", Range(0, 1)) = 0
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#define DegreeToRadian 0.0174533

			half4 _Color;
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;
			TEXTURE2D(_Ramp);
			SAMPLER(sampler_Ramp);
			half4 _Specular;
			half _SpecularScale;
			float _TranslationX;
			float _TranslationY;
			float _RotationX;
			float _RotationY;
			float _RotationZ;
			float _ScaleX;
			float _ScaleY;
			float _SplitX;
			float _SplitY;
			float _SquareN;
			half _SquareScale;

			struct a2v
			{
				float4 vertex:POSITION;
				float3 normal:NORMAL;
				float4 texcoord:TEXCOORD0;
				float4 tangent:TANGENT;
			};

			struct v2f
			{
				float4 pos:SV_POSITION;
				float2 uv:texcood0;
				float3 tangentNormal:TEXCOORD1;
				float3 tangentLightDir:TEXCOORD2;
				float3 tangentViewDir:TEXCOORD3;
				float3 worldPos:TEXCOORD4;
			};

			v2f vert(a2v IN)
			{
				v2f o;

				o.pos = TransformObjectToHClip(IN.vertex);
				// o.tangentNormal = TransformObjectToTangent()
				//TODO:

			}
			
			ENDHLSL
		}
	}
}