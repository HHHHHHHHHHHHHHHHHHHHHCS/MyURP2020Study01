using Graphics.Scripts.UnityChanSSU;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace Graphics.Editor.UnityChanSSU
{
	[VolumeComponentEditor(typeof(MyVignettePostProcess))]
	public class MyVignettePostProcessEditor : VolumeComponentEditor
	{
		private SerializedDataParameter m_Mode;
		private SerializedDataParameter m_Color;

		private SerializedDataParameter m_Center;
		private SerializedDataParameter m_Intensity;
		private SerializedDataParameter m_Smoothness;
		private SerializedDataParameter m_Roundness;
		private SerializedDataParameter m_Rounded;

		private SerializedDataParameter m_Mask;
		private SerializedDataParameter m_Opacity;

		public override void OnEnable()
		{
			var o = new PropertyFetcher<MyVignettePostProcess>(serializedObject);
			
			m_Mode = Unpack(o.Find(x => x.mode));
			m_Color = Unpack(o.Find(x => x.color));

			m_Center = Unpack(o.Find(x => x.center));
			m_Intensity = Unpack(o.Find(x => x.intensity));
			m_Smoothness = Unpack(o.Find(x => x.smoothness));
			m_Roundness = Unpack(o.Find(x => x.roundness));
			m_Rounded = Unpack(o.Find(x => x.rounded));

			m_Mask = Unpack(o.Find(x => x.mask));
			m_Opacity = Unpack(o.Find(x => x.opacity));
		}

		public override void OnInspectorGUI()
		{
			// if (UniversalRenderPipeline.asset?.postProcessingFeatureSet == PostProcessingFeatureSet.PostProcessingV2)
			// {
			// 	EditorGUILayout.HelpBox(UniversalRenderPipelineAssetEditor.Styles.postProcessingGlobalWarning,
			// 		MessageType.Warning);
			// 	return;
			// }

			PropertyField(m_Mode);
			PropertyField(m_Color);

			if (m_Mode.value.intValue == (int)VignetteMode.Classic)
			{
				PropertyField(m_Center);
				PropertyField(m_Intensity);
				PropertyField(m_Smoothness);
				PropertyField(m_Roundness);
				PropertyField(m_Rounded);
			}
			else
			{
				PropertyField(m_Mask);

				var mask = (target as MyVignettePostProcess)?.mask.value;

				// Checks import settings on the mask
				if (mask != null)
				{
					var importer = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(mask)) as TextureImporter;

					// Fails when using an internal texture as you can't change import settings on
					// builtin resources, thus the check for null
					if (importer != null)
					{
						bool valid = importer.anisoLevel == 0
						             && importer.mipmapEnabled == false
						             && importer.alphaSource == TextureImporterAlphaSource.FromGrayScale
						             && importer.textureCompression == TextureImporterCompression.Uncompressed
						             && importer.wrapMode == TextureWrapMode.Clamp;

						if (!valid)
						{
							CoreEditorUtils.DrawFixMeBox("Invalid mask import settings.", () => SetMaskImportSettings(importer));
						}
					}
				}

				PropertyField(m_Opacity);
			}
		}
		
		private void SetMaskImportSettings(TextureImporter importer)
		{
			importer.textureType = TextureImporterType.SingleChannel;
			importer.alphaSource = TextureImporterAlphaSource.FromGrayScale;
			importer.textureCompression = TextureImporterCompression.Uncompressed;
			importer.anisoLevel = 0;
			importer.mipmapEnabled = false;
			importer.wrapMode = TextureWrapMode.Clamp;
			importer.SaveAndReimport();
			AssetDatabase.Refresh();
		}
	}
}