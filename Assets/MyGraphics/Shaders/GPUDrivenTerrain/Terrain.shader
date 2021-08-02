Shader "MyRP/GPUDrivenTerrain/Terrain"
{
	Properties
	{
//		_MainTex("Main Texture", 2D) = "white"{}
//		_HeightMap("Height Map", 2D) = "white"{}
//		_NormalMap("Normal Map", 2D) = "white"{}
	}
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque" "LightMode" = "UniversalForwad"
		}

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			#include "CommonInput.hlsl"

			#pragma shader_feature _ENABLE_MIP_DEBUG
			#pragma shader_feature _ENABLE_PATCH_DEBUG
			#pragma shader_feature _ENABLE_LOD_SEAMLESS
			#pragma shader_feature _ENABLE_NODE_DEBUG

			struct a2v
			{
				float4 vertex: POSITION;
				float2 uv : TEXCOORD0;
				uint instanceID : SV_InstanceID;
			};

			struct v2f
			{
				float2 uv : TEXCOOD0;
				float4 vertex : SV_POSITION;
				float3 color : TEXCOORD1;
			};

			StructuredBuffer<RenderPatch> _PatchList;

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;
			TEXTURE2D(_HeightMap);
			SAMPLER(sampler_HeightMap);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);
			float3 _WorldSize;
			float4x4 _WorldToNormalMapMatrix;

			static half3 debugColorForMip[6] = {
				half3(0, 1, 0),
				half3(0, 0, 1),
				half3(1, 0, 0),
				half3(1, 1, 0),
				half3(0, 1, 1),
				half3(1, 0, 1),
			};

			float3 TransformNormalToWorldSpace(float3 normal)
			{
				return SafeNormalize(mul(normal, (float3x3)_WorldToNormalMapMatrix));
			}


			float3 SampleNormal(float2 uv)
			{
				float3 normal;
				normal.xz = SAMPLE_TEXTURE2D_LOD(_NormalMap, sampler_NormalMap, uv, 0).xy * 2 - 1;
				normal.y = sqrt(max(0, 1 - dot(normal.xz, normal.xz)));
				normal = TransformNormalToWorldSpace(normal);
				return normal;
			}


			//修复接缝
			void FixLODConnectSeam(inout float4 vertex, inout float2 uv, RenderPatch patch)
			{
				uint4 lodTrans = patch.lodTrans;
				uint2 vertexIndex = floor((vertex.xz + PATCH_MESH_SIZE * 0.5 + 0.01) / PATCH_MESH_GRID_SIZE);
				float uvGridStrip = 1.0 / PATCH_MESH_GRID_COUNT;

				//左下右上 边界做连接

				uint lodDelta = lodTrans.x;
				if (lodDelta > 0 && vertexIndex.x == 0)
				{
					uint gridStripCount = pow(2, lodDelta);
					uint modIndex = vertexIndex.y % gridStripCount;
					if (modIndex != 0)
					{
						vertex.z -= PATCH_MESH_GRID_SIZE * modIndex;
						uv.y -= uvGridStrip * modIndex;
						return;
					}
				}


				lodDelta = lodTrans.y;
				if (lodDelta > 0 && vertexIndex.y == 0)
				{
					uint gridStripCount = pow(2, lodDelta);
					uint modIndex = vertexIndex.x % gridStripCount;
					if (modIndex != 0)
					{
						vertex.x -= PATCH_MESH_GRID_SIZE * modIndex;
						uv.x -= uvGridStrip * modIndex;
						return;
					}
				}

				lodDelta = lodTrans.z;
				if (lodDelta > 0 && vertexIndex.x == PATCH_MESH_GRID_COUNT)
				{
					uint gridStripCount = pow(2, lodDelta);
					uint modIndex = vertexIndex.y % gridStripCount;
					if (modIndex != 0)
					{
						vertex.z += PATCH_MESH_GRID_SIZE * (gridStripCount - modIndex);
						uv.y += uvGridStrip * (gridStripCount - modIndex);
						return;
					}
				}

				lodDelta = lodTrans.w;
				if (lodDelta > 0 && vertexIndex.y == PATCH_MESH_GRID_COUNT)
				{
					uint gridStripCount = pow(2, lodDelta);
					uint modIndex = vertexIndex.x % gridStripCount;
					if (modIndex != 0)
					{
						vertex.x += PATCH_MESH_GRID_SIZE * (gridStripCount - modIndex);
						uv.x += uvGridStrip * (gridStripCount - modIndex);
						return;
					}
				}
			}

			//在Node之间留出缝隙供debug
			float3 ApplyNodeDebug(RenderPatch patch, float3 vertex)
			{
				uint nodeCount = (uint)(5 * pow(2, 5 - patch.lod));
				float nodeSize = _WorldSize.x / nodeCount;
				uint2 nodeLoc = floor((patch.position + _WorldSize.xz * 0.5) / nodeSize);
				float2 nodeCenterPosition = -_WorldSize.xz * 0.5 + (nodeLoc + 0.5) * nodeSize;
				vertex.xz = nodeCenterPosition + (vertex.xz - nodeCenterPosition) * 0.95;
				return vertex;
			}

			v2f vert(a2v IN)
			{
				v2f o;

				float4 inVertex = IN.vertex;
				float2 uv = IN.uv;

				RenderPatch patch = _PatchList[IN.instanceID];

				#if _ENABLE_LOD_SEAMLESS
				FixLODConnectSeam(inVertex, uv, patch);
				#endif

				uint lod = patch.lod;
				float scale = pow(2, lod);

				inVertex.xz *= scale;
				#if _ENABLE_PATCH_DEBUG
				inVertex.xz *= 0.9;
				#endif

				inVertex.xz += patch.position;

				#if _ENABLE_NODE_DEBUG
				inVertex.xyz = ApplyNodeDebug(patch, inVertex.xyz);
				#endif

				float2 heightUV = (inVertex.xz + (_WorldSize.xz * 0.5) + 0.5) / (_WorldSize.xz + 1);
				float height = SAMPLE_TEXTURE2D_LOD(_HeightMap, sampler_HeightMap, heightUV, 0).r;
				inVertex.y = height * _WorldSize.y;

				float3 normal = SampleNormal(heightUV);
				Light light = GetMainLight();
				o.color = max(0.05, dot(light.direction, normal));

				float4 vertex = TransformObjectToHClip(inVertex.xyz);
				o.vertex = vertex;
				o.uv = uv * scale * 8;

				#if _ENABLE_MIP_DEBUG
				uint4 lodTrans = patch.lodTrans;
				uint4 lodColorIndex = lod + lodTrans;
				o.color *= (debugColorForMip[lodColorIndex.x] +
					debugColorForMip[lodColorIndex.y] +
					debugColorForMip[lodColorIndex.z] +
					debugColorForMip[lodColorIndex.w]) * 0.25;
				#endif

				return o;
			}

			half4 frag(v2f IN):SV_Target
			{
				half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
				col.rgb *= IN.color;
				return col;
			}
			ENDHLSL
		}
	}
}