using Unity.Mathematics;
using UnityEditor;
using UnityEngine;

namespace MyGraphics.Editor.Other
{
	public class CustomMeshChangeEditor
	{
		/*
		// Encoding/decoding [0..1) floats into 8 bit/channel RGBA. Note that 1.0 will not be encoded properly.
		inline float4 EncodeFloatRGBA( float v )
		{
		    float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
		    float kEncodeBit = 1.0/255.0;
		    float4 enc = kEncodeMul * v;
		    enc = frac (enc);
		    enc -= enc.yzww * kEncodeBit;
		    return enc;
		}
		inline float DecodeFloatRGBA( float4 enc )
		{
		    float4 kDecodeDot = float4(1.0, 1/255.0, 1/65025.0, 1/16581375.0);
		    return dot( enc, kDecodeDot );
		}

		// Encoding/decoding [0..1) floats into 8 bit/channel RG. Note that 1.0 will not be encoded properly.
		inline float2 EncodeFloatRG( float v )
		{
		    float2 kEncodeMul = float2(1.0, 255.0);
		    float kEncodeBit = 1.0/255.0;
		    float2 enc = kEncodeMul * v;
		    enc = frac (enc);
		    enc.x -= enc.y * kEncodeBit;
		    return enc;
		}
		inline float DecodeFloatRG( float2 enc )
		{
		    float2 kDecodeDot = float2(1.0, 1/255.0);
		    return dot( enc, kDecodeDot );
		}
		*/


		private static float4 EncodeFloatRGBA(float v)
		{
			float4 kEncodeMul = new float4(1.0f, 255.0f, 65025.0f, 16581375.0f);
			float kEncodeBit = 1.0f / 255.0f;
			float4 enc = kEncodeMul * v;
			enc = math.frac(enc);
			enc -= enc.yzww * kEncodeBit;
			return enc;
		}

		private static float DecodeFloatRGBA(float4 enc)
		{
			float4 kDecodeDot = new float4(1.0f, 1 / 255.0f, 1 / 65025.0f, 1 / 16581375.0f);
			return math.dot(enc, kDecodeDot);
		}

		[MenuItem("GameObject/CustomMeshChange", false, 40)]
		private static void ConvertAssets(MenuCommand command)
		{
			GameObject currObj;


			if (command == null || command.context == null)
			{
				// We were actually invoked from the top GameObject menu, so use the selection.
				var selection = Selection.GetFiltered<GameObject>(SelectionMode.Editable | SelectionMode.TopLevel);
				if (selection == null || selection.Length == 0)
				{
					Debug.Log("Selection Object is null.");
					return;
				}

				currObj = selection[0];
			}
			else
			{
				// We were invoked from the right-click menu, so use the context of the context menu.
				var selected = command.context as GameObject;
				if (selected == null)
				{
					Debug.Log("MenuCommand Object is null.");
					return;
				}

				currObj = selected;
			}

			Mesh oldMesh = currObj.GetComponent<MeshFilter>()?.sharedMesh;

			if (oldMesh == null)
			{
				Debug.Log("Can't find mesh.");
				return;
			}

			Mesh newMesh = new Mesh();
			newMesh.name = oldMesh.name;
			newMesh.SetVertices(oldMesh.vertices);
			newMesh.SetNormals(oldMesh.normals);
			newMesh.SetTangents(oldMesh.tangents);
			newMesh.subMeshCount = oldMesh.subMeshCount;
			for (int i = 0; i < newMesh.subMeshCount; i++)
			{
				newMesh.SetIndices(oldMesh.GetIndices(i), oldMesh.GetTopology(i), i);
			}

			newMesh.SetUVs(0, oldMesh.uv);
			newMesh.SetUVs(1, oldMesh.uv3);


			var uv2 = oldMesh.uv2;
			Color[] colors = new Color[uv2.Length];
			for (int i = 0; i < uv2.Length; i++)
			{
				var v2 = uv2[i];
				float4 v0 = EncodeFloatRGBA(v2.x);
				float4 v1 = EncodeFloatRGBA(v2.y);
				colors[i] = new Color(v0.x, v0.y, v1.x, v1.y);
			}

			newMesh.SetColors(colors);
			newMesh.bounds = oldMesh.bounds;
			
			AssetDatabase.CreateAsset(newMesh, "Assets/" + newMesh.name + ".asset");
			AssetDatabase.Refresh();
		}
	}
}