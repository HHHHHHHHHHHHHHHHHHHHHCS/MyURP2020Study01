using System;
using System.Collections.Generic;
using UnityEngine;

namespace Graphics.Scripts.ScreenEffect.FlipBook
{
	//todo: 写个cmd copy texture 给rt
	//绘制mesh 给屏幕
	//先抄袭shader
	//如果有SSAO 或者给模型的周围的顶点属性添加标记    可以制造阴影  效果更好
	public class FlipBookCtrl : MonoBehaviour
	{
		#region Editable attributes

		[SerializeField] private bool _useOriginalResolution = true;

		[SerializeField] private Vector2Int _resolution = new Vector2Int(1280, 720);

		[SerializeField] private int _pageCount = 15;

		[SerializeField, Range(0.02f, 1f)] private float _interval = 0.1f;

		[SerializeField, Range(0.1f, 8.0f)] private float _speed = 0.1f;

		#endregion

		#region Project asset references

		[SerializeField] private Mesh _mesh = null;

		[SerializeField] private Shader _shader = null;

		#endregion

		#region Private variables

		private float timer = 0;

		private List<FlipBookPage> _pages = new List<FlipBookPage>();

		private FlipBookPass _flipBookPass;

		#endregion

		private void OnValidate()
		{
			_resolution = Vector2Int.Max(_resolution, Vector2Int.one * 32);
			_resolution = Vector2Int.Min(_resolution, Vector2Int.one * 2048);
			_interval = Mathf.Max(_interval, 1.0f / 60);
		}

		private void Start()
		{
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


			_pages = new List<FlipBookPage>(_pageCount);
			for (var i = 0; i < _pageCount; i++)
			{
				_pages.Add(FlipBookPage.Allocate(i, w, h));
			}

			_flipBookPass = new FlipBookPass();
			_flipBookPass.Init(_mesh, _shader, _pages);


			ScreenEffectMono.pass = _flipBookPass;
		}

		private void Update()
		{
			float time = 0;
			timer += Time.deltaTime;
			if (timer > _interval)
			{
				time = Time.time;
				timer %= _interval; // 为什么不用减法  因为怕time.deltaTime 过大
			}

			_flipBookPass.Setup(_speed, time);
		}

		private void OnDestroy()
		{
			_flipBookPass.OnDestroy();


			foreach (var page in _pages)
			{
				FlipBookPage.Deallocate(page);
			}

			_pages.Clear();
		}
	}
}