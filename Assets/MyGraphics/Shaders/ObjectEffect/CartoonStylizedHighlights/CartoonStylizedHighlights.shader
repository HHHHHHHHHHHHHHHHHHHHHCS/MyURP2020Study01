///  Reference: 	Anjyo K, Hiramitsu K. Stylized highlights for cartoon rendering and animation[J]. 
///						Computer Graphics and Applications, IEEE, 2003, 23(4): 54-61.

//本来卡通还有outline 阴影什么的  这里偷懒就做一个高光
//By https://github.com/candycat1992/NPR_Lab
Shader "MyRP/ObjectEffect/CartoonStylizedHighlights"
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
				float2 texcoord:TEXCOORD0;
				float3 normal:NORMAL;
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

				//这个会to world  不是我们想要的
				// VertexNormalInputs TBNs = GetVertexNormalInputs(IN.normal, IN.tangent);

				float3 binormal = cross(normalize(IN.normal), normalize(IN.tangent.xyz)) * IN.tangent.w * GetOddNegativeScale();
				float3x3 rotation = float3x3(IN.tangent.xyz, binormal, IN.normal);

				o.tangentNormal = mul(rotation, IN.normal); // Equal to (0, 0, 1)
				o.tangentLightDir = mul(rotation, TransformWorldToObjectDir(_MainLightPosition.xyz));
				o.tangentViewDir = mul(rotation, TransformWorldToObject(_WorldSpaceCameraPos) - IN.vertex.xyz);

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
				//这里取出符号进行分割
				half signX = sign(tangentHalfDir.x);
				half signY = sign(tangentHalfDir.y);
				tangentHalfDir = tangentHalfDir - _SplitX * signX * half3(1, 0, 0) - _SplitY * signY * half3(0, 1, 0);
				tangentHalfDir = normalize(tangentHalfDir);

				//Square
				float sqrThetaX = acos(tangentHalfDir.x);
				float sqrThetaY = acos(tangentHalfDir.y);
				half sqrNormalX = sin(pow(2 * sqrThetaX, _SquareN));
				half sqrNormalY = sin(pow(2 * sqrThetaY, _SquareN));
				tangentHalfDir = tangentHalfDir - _SquareScale * (sqrNormalX * tangentHalfDir.x * half3(1, 0, 0) +
					sqrNormalY * tangentHalfDir.y * half3(0, 1, 0));
				tangentHalfDir = normalize(tangentHalfDir);

				//Compute the lighting model
				half3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;

				float atten = 1.0;

				half diff = dot(tangentNormal, tangentLightDir);
				diff = diff * 0.5 + 0.5;

				half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
				half3 diffuseColor = c.rgb * _Color.rgb;
				half3 diffuse = _MainLightColor.rgb * diffuseColor
					* SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(diff,diff)).rgb;

				half spec = dot(tangentNormal, tangentHalfDir);
				half w = fwidth(spec) * 1.0;
				half3 specular = lerp(half3(0, 0, 0), _Specular.rgb, smoothstep(-w, w, spec + _SpecularScale - 1));

				return half4(ambient + (diffuse + specular) * atten, 1.0);
			}
			ENDHLSL
		}
	}
}