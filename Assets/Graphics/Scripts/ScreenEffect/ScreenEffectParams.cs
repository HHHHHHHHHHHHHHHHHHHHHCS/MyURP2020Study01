using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Graphics.Scripts.ScreenEffect
{
	[System.Serializable,
	 CreateAssetMenu(fileName = "ScreenEffectParamsData", menuName = "ScreenEffect/Params", order = 1)]
	public class ScreenEffectParams : ScriptableObject
	{
		[SerializeField] public Dictionary<string, int> intDict = new Dictionary<string, int>();
		[SerializeField] public Dictionary<string, float> floatDict = new Dictionary<string, float>();
		[SerializeField] public Dictionary<string, Vector4> vector4Dict = new Dictionary<string, Vector4>();

		public void SetParams(Material mat)
		{
			foreach (var item in intDict)
			{
				mat.SetInt(item.Key, item.Value);
			}
			foreach (var item in floatDict)
			{
				mat.SetFloat(item.Key, item.Value);
			}
			foreach (var item in vector4Dict)
			{
				mat.SetVector(item.Key, item.Value);
			}
		}
		
		public void SetParams(CommandBuffer cmd)
		{
			foreach (var item in intDict)
			{
				cmd.SetGlobalInt(item.Key, item.Value);
			}
			foreach (var item in floatDict)
			{
				cmd.SetGlobalFloat(item.Key, item.Value);
			}
			foreach (var item in vector4Dict)
			{
				cmd.SetGlobalVector(item.Key, item.Value);
			}
		}
	}
}