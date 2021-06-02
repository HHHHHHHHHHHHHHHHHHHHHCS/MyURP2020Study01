using System;
using System.Collections.Generic;
using UnityEngine;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	//todo: 写个cmd copy texture 给rt
	//绘制mesh 给屏幕
	//如果有SSAO 或者给模型的周围的顶点属性添加标记    可以制造阴影  效果更好
	public class FlipBookCtrl : MonoBehaviour
	{
		#region Editable attributes

		[SerializeField] private Camera _sourceCamera = null;

		[SerializeField] private bool _useOriginalResolution = true;

		[SerializeField] private Vector2Int _resolution = new Vector2Int(1280, 720);

		[SerializeField] private int _pageCount = 15;

		[SerializeField, Range(0.02f, 0.2f)] private float _interval = 0.1f;

		[SerializeField, Range(0.1f, 8.0f)] private float _speed = 0.1f;

		#endregion

		#region Project asset references

		[SerializeField, HideInInspector] private Mesh _mesh = null;

		[SerializeField, HideInInspector] private Shader _shader = null;

		#endregion

		#region Private variables

		private Material _material;

		private RenderTexture _rt;

		private Queue<FlipBookPage> _pages = new Queue<FlipBookPage>();

		private float _timer;

		#endregion

		private void OnValidate()
		{
			_resolution = Vector2Int.Max(_resolution, Vector2Int.one * 32);
			_resolution = Vector2Int.Min(_resolution, Vector2Int.one * 2048);
			_interval = Mathf.Max(_interval, 1.0f / 60);
		}

		private void Start()
		{
			_material = new Material(_shader);

			int w, h;
			if (_useOriginalResolution)
			{
				w = Screen.width;
				h = Screen.height;
			}
			else
			{
				w = _resolution.x;
				h = _resolution.y;
			}

			_rt = new RenderTexture(w, h, 0);
			//set camera target

			for (var i = 0; i < _pageCount; i++)
			{
				// _pages.Enqueue();
			}
		}

		private void OnDestroy()
		{
			if (_material)
			{
				Destroy(_material);
				_material = null;
			}
		}

		// private void Update()
		// {
		// 	_timer += Time.deltaTime;
		//
		// 	if (_timer > _interval)
		// 	{
		// 		_pages.Enqueue();
		// 		_timer %= _interval;
		// 	}
		// }
	}
}