using UnityEngine;

namespace Common.CommonScripts
{
	public class AnimationController : MonoBehaviour
	{
		public GameObject seesawObj;
		public GameObject xRotObj;
		public GameObject yRotObj;
		public GameObject scaleObj;

		private Vector3 seesawPos;

		void Start()
		{
			seesawPos = seesawObj.transform.position;
		}

		void Update()
		{
			seesawObj.transform.position = seesawPos + 2.0f * new Vector3(0.0f, Mathf.Sin(2.0f * Time.time), 0.0f);
			xRotObj.transform.Rotate(new Vector3(10 * Time.deltaTime, 0.0f, 0.0f), Space.Self);
			yRotObj.transform.Rotate(new Vector3(0.0f, 10 * Time.deltaTime, 0.0f), Space.Self);
			float scale = Mathf.Sin(Time.time) * 0.5f + 1.0f;
			scaleObj.transform.localScale = new Vector3(scale, scale, scale);
		}
	}
}