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
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

				o.worldPos = TransformObjectToWorld(IN.vertex.xyz);
				o.pos = TransformWorldToHClip(o.worldPos);

				VertexNormalInputs TBNs = GetVertexNormalInputs(IN.normal, IN.tangent);
				float3x3 rotation = float3x3(TBNs.tangentWS, TBNs.bitangentWS, TBNs.normalWS);

				o.tangentNormal = mul(rotation, IN.normal);
				o.tangentLightDir = mul(rotation, _MainLightPosition.xyz);
				o.tangentNormal = mul(rotation, GetWorldSpaceViewDir(o.worldPos));

				o.uv = TRANSFORM_TEX(IN.texcoord, _MainTex);

				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half3 tangentNormal = normalize(IN.tangentNormal);
				half3 tangentLightDir = normalize(IN.tangentLightDir);
				half3 tangentViewDir = normalize(IN.tangentViewDir);
				half3 tangentHalfDir = normalize(tangentViewDir + tangentLightDir);

				//Scale
				tangentHalfDir = tangentHalfDir - _ScaleX * tangentHalfDir.x * half3(1, 0, 0);
				tangentHalfDir = normalize(tangentHalfDir);
				tangentHalfDir = tangentHalfDir - _ScaleY * tangentHalfDir.y * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);

				//Rotation
				float xRad = _RotationX * DegreeToRadian;
				float3x3 xRotation = float3x3(1, 0, 0,
				                              0, cos(xRad), sin(xRad),
				                              0, -sin(xRad), cos(xRad)
				);
				float yRad = _RotationY * DegreeToRadian;
				float3x3 yRotation = float3x3(cos(yRad), 0, -sin(yRad),
				                              0, 1, 0,
				                              sin(yRad), 0, cos(yRad));
				float zRad = _RotationZ * DegreeToRadian;
				float3x3 zRotation = float3x3(cos(zRad), sin(zRad), 0,
				                              -sin(zRad), cos(zRad), 0,
				                              0, 0, 1);
				tangentHalfDir = mul(zRotation, mul(yRotation, mul(xRotation, tangentHalfDir)));


				//Translation
				tangentHalfDir = tangentHalfDir + half3(_TranslationX, _TranslationY, 0);
				tangentHalfDir = normalize(tangentHalfDir);

				//Split
				half signX = sign(tangentHalfDir.x);
				half signY = sign(tangentHalfDir.y);
				tangentHalfDir = tangentHalfDir - _SplitX * signX * half3(1, 0, 0) - _SplitY * signY * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);

				//Square
				float sqrThetaX = acos(tangentHalfDir.x);
				float sqrThetaY = acos(tangentHalfDir.y);
				half sqrNormalX = sin(pow(2 * sqrThetaX, _SquareN));
				half sqrNormalY = sin(pow(2 * sqrThetaY, _SquareN));
				tangentHalfDir = tangentHalfDir - _SquareScale * (sqrNormalX * tangentHalfDir * half3(1, 0, 0) +
					sqrNormalY * tangentHalfDir.y * half3(0, 1, 0));
				tangentHalfDir = normalize(tangentHalfDir);

				return 1;
			}
			ENDHLSL
		}
	}
}