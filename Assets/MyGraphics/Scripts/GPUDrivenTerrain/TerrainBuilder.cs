using System;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace MyGraphics.Scripts.GPUDrivenTerrain
{
	public class TerrainBuilder : IDisposable
	{
		public class ShaderConstants
		{
			public const string k_ENABLE_SEAM = "_ENABLE_SEAM";
			public const string k_ENABLE_FRUS_CULL = "_ENABLE_FRUS_CULL";
			public const string k_ENABLE_HIZ_CULL = "_ENABLE_HIZ_CULL";
			public const string k_BOUNDS_DEBUG = "_BOUNDS_DEBUG";

			public static readonly int WorldSize_ID = Shader.PropertyToID("_WorldSize");
			public static readonly int CameraPositionWS_ID = Shader.PropertyToID("_CameraPositionWS");
			public static readonly int CameraFrustumPlanes_ID = Shader.PropertyToID("_CameraFrustumPlanes");
			public static readonly int PassLOD_ID = Shader.PropertyToID("_PassLOD");
			public static readonly int AppendFinalNodeList_ID = Shader.PropertyToID("_AppendFinalNodeList");
			public static readonly int FinalNodeList_ID = Shader.PropertyToID("_FinalNodeList");
			public static readonly int CulledPatchList_ID = Shader.PropertyToID("_CulledPatchList");
			public static readonly int PatchBoundsList_ID = Shader.PropertyToID("_PatchBoundsList");

			public static readonly int AppendNodeList_ID = Shader.PropertyToID("_AppendNodeList");
			public static readonly int ConsumeNodeList_ID = Shader.PropertyToID("_ConsumeNodeList");
			public static readonly int NodeEvaluationC_ID = Shader.PropertyToID("_NodeEvaluationC");
			public static readonly int WorldLodParams_ID = Shader.PropertyToID("_WorldLodParams");

			public static readonly int NodeDescriptors_ID = Shader.PropertyToID("_NodeDescriptors");
			public static readonly int NodeIDOffsetOfLOD_ID = Shader.PropertyToID("_NodeIDOffsetOfLOD");

			public static readonly int LodMap_ID = Shader.PropertyToID("_LodMap");
			public static readonly int MinMaxHeightTexture_ID = Shader.PropertyToID("_MinMaxHeightTexture");

			public static readonly int BoundsHeightRedundance_ID = Shader.PropertyToID("_BoundsHeightRedundance");
			public static readonly int HizDepthBias_ID = Shader.PropertyToID("_HizDepthBias");
		}

		private const int PatchStripSize = 9 * 4;

		private Vector4 _nodeEvaluationC = new Vector4(1, 0, 0, 0);
		private bool _isNodeEvaluationCDirty = true;

		private float _hizDepthBias = 1;

		private TerrainAsset _asset;

		private Plane[] _cameraFrustumPlanes = new Plane[6];
		private Vector4[] _cameraFrustumPlanesV4 = new Vector4[6];

		private int _kernelOfTraverseQuadTree;
		private int _kernelOfBuildLodMap;
		private int _kernelOfBuildPatches;

		/// <summary>
		/// Buffer的大小需要根据预估的最大分割情况进行分配.
		/// </summary>
		private int _maxNodeBufferSize = 200;

		private int _tempNodeBufferSize = 50;

		private bool _isBoundsBufferOn;

		private ComputeShader _computeShader;

		private CommandBuffer _commandBuffer;

		private ComputeBuffer _maxLODNodeList;
		private ComputeBuffer _nodeListA;
		private ComputeBuffer _nodeListB;
		private ComputeBuffer _finalNodeListBuffer;
		private ComputeBuffer _nodeDescriptors;

		private ComputeBuffer _culledPatchBuffer;

		private ComputeBuffer _patchIndirectArgs;
		private ComputeBuffer _patchBoundsBuffer;
		private ComputeBuffer _patchBoundsIndirectArgs;
		private ComputeBuffer _indirectArgsBuffer;
		private RenderTexture _lodMap;


		public int boundsHeightRedundance
		{
			set => _computeShader.SetInt(ShaderConstants.BoundsHeightRedundance_ID, value);
		}

		public float nodeEvalDistance
		{
			set
			{
				_nodeEvaluationC.x = value;
				_isNodeEvaluationCDirty = true;
			}
		}

		public bool enableSeamDebug
		{
			set => CoreUtils.SetKeyword(_computeShader, ShaderConstants.k_ENABLE_SEAM, value);
		}

		public float hizDepthBias
		{
			set
			{
				_hizDepthBias = Mathf.Clamp(value, 0.01f, 1000f);
				_computeShader.SetFloat(ShaderConstants.HizDepthBias_ID, _hizDepthBias);
			}
			get => _hizDepthBias;
		}


		public bool isFrustumCullEnabled
		{
			set => CoreUtils.SetKeyword(_computeShader, ShaderConstants.k_ENABLE_FRUS_CULL, value);
		}

		public bool isHizOcclusionCullingEnabled
		{
			set => CoreUtils.SetKeyword(_computeShader, ShaderConstants.k_ENABLE_HIZ_CULL, value);
		}


		public bool isBoundsBufferOn
		{
			set
			{
				CoreUtils.SetKeyword(_computeShader, ShaderConstants.k_BOUNDS_DEBUG, value);

				_isBoundsBufferOn = value;
			}
			get => _isBoundsBufferOn;
		}


		public ComputeBuffer patchIndirectArgs => _patchIndirectArgs;

		public ComputeBuffer culledPatchBuffer => _culledPatchBuffer;

		public ComputeBuffer nodeIDList => _finalNodeListBuffer;

		public ComputeBuffer patchBoundsBuffer => _patchBoundsBuffer;

		public ComputeBuffer boundsIndirectArgs => _patchBoundsIndirectArgs;

		public TerrainBuilder(TerrainAsset asset)
		{
			_asset = asset;
			_computeShader = asset.computeShader;
			_commandBuffer = new CommandBuffer
			{
				name = "TerrainBuilder"
			};
			_culledPatchBuffer = new ComputeBuffer(_maxNodeBufferSize * 64, PatchStripSize, ComputeBufferType.Append);

			_patchIndirectArgs = new ComputeBuffer(5, 4, ComputeBufferType.IndirectArguments);
			_patchBoundsBuffer.SetData(new uint[] {TerrainAsset.patchMesh.GetIndexCount(0), 0, 0, 0, 0});

			_patchBoundsIndirectArgs = new ComputeBuffer(5, 4, ComputeBufferType.IndirectArguments);
			_patchBoundsIndirectArgs.SetData(new uint[] {TerrainAsset.unitCubeMesh.GetIndexCount(0), 0, 0, 0, 0});

			_maxLODNodeList = new ComputeBuffer(TerrainAsset.MAX_LOD_NODE_COUNT * TerrainAsset.MAX_LOD_NODE_COUNT, 8,
				ComputeBufferType.Append);
			InitMaxLODNodeListDatas();

			_nodeListA = new ComputeBuffer(_tempNodeBufferSize, 8, ComputeBufferType.Append);
			_nodeListB = new ComputeBuffer(_tempNodeBufferSize, 8, ComputeBufferType.Append);
			_indirectArgsBuffer = new ComputeBuffer(3, 4, ComputeBufferType.IndirectArguments);
			_indirectArgsBuffer.SetData(new uint[] {1, 1, 1});
			_finalNodeListBuffer = new ComputeBuffer(_maxNodeBufferSize, 12, ComputeBufferType.Append);
			_nodeDescriptors = new ComputeBuffer((int) (TerrainAsset.MAX_NODE_ID + 1), 4);

			_patchBoundsBuffer = new ComputeBuffer(_maxNodeBufferSize * 64, 4 * 10, ComputeBufferType.Append);

			_lodMap = TextureUtility.CreateLODMap(160);

			CoreUtils.SetKeyword(_computeShader, "_REVERSE_Z", SystemInfo.usesReversedZBuffer);

			InitKernels();
			InitWorldParams();

			boundsHeightRedundance = 5;
			hizDepthBias = 1;
		}

		private void InitMaxLODNodeListDatas()
		{
			var maxLODNodeCount = TerrainAsset.MAX_LOD_NODE_COUNT;
			uint2[] datas = new uint2[maxLODNodeCount * maxLODNodeCount];
			var index = 0;
			for (uint i = 0; i < maxLODNodeCount; i++)
			{
				for (uint j = 0; j < maxLODNodeCount; j++)
				{
					datas[index] = new uint2(i, j);
					index++;
				}
			}

			_maxLODNodeList.SetData(datas);
		}

		private void InitKernels()
		{
			_kernelOfTraverseQuadTree = _computeShader.FindKernel("TraverseQuadTree");
			_kernelOfBuildLodMap = _computeShader.FindKernel("BuildLodMap");
			_kernelOfBuildPatches = _computeShader.FindKernel("BuildPatches");
			BindComputeShader(_kernelOfTraverseQuadTree);
			BindComputeShader(_kernelOfBuildLodMap);
			BindComputeShader(_kernelOfBuildPatches);
		}

		private void BindComputeShader(int kernelIndex)
		{
			// _computeShader.SetTexture(kernelIndex, "_QuadTreeTexture", _asset.quadTreeMap);
			if (kernelIndex == _kernelOfTraverseQuadTree)
			{
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.AppendFinalNodeList_ID, _finalNodeListBuffer);
				_computeShader.SetTexture(kernelIndex, ShaderConstants.MinMaxHeightTexture_ID, _asset.minMaxHeightMap);
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.NodeDescriptors_ID, _nodeDescriptors);
			}
			else if (kernelIndex == _kernelOfBuildLodMap)
			{
				_computeShader.SetTexture(kernelIndex, ShaderConstants.LodMap_ID, _lodMap);
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.NodeDescriptors_ID, _nodeDescriptors);
			}
			else if (kernelIndex == _kernelOfBuildPatches)
			{
				_computeShader.SetTexture(kernelIndex, ShaderConstants.LodMap_ID, _lodMap);
				_computeShader.SetTexture(kernelIndex, ShaderConstants.MinMaxHeightTexture_ID, _asset.minMaxHeightMap);
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.FinalNodeList_ID, _finalNodeListBuffer);
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.CulledPatchList_ID, _culledPatchBuffer);
				_computeShader.SetBuffer(kernelIndex, ShaderConstants.PatchBoundsList_ID, _patchBoundsBuffer);
			}
		}

		private void InitWorldParams()
		{
			float wSize = _asset.worldSize.x;
			int nodeCount = TerrainAsset.MAX_LOD_NODE_COUNT;
			Vector4[] worldLODParams = new Vector4[TerrainAsset.MAX_LOD + 1];
			for (var lod = TerrainAsset.MAX_LOD; lod >= 0; lod--)
			{
				var nodeSize = wSize / nodeCount;
				var patchExtent = nodeSize / 16; //即 /8(node数量) /2 (halfSize)
				var sectorCountPerNode = (int) Mathf.Pow(2, lod);
				worldLODParams[lod] = new Vector4(nodeSize, patchExtent, nodeCount, sectorCountPerNode);
				nodeCount *= 2;
			}

			_computeShader.SetVectorArray(ShaderConstants.WorldLodParams_ID, worldLODParams);

			int[] nodeIDOffsetLOD = new int[(TerrainAsset.MAX_LOD + 1) * 4];
			int nodeIdOffset = 0;
			for (int lod = TerrainAsset.MAX_LOD; lod >= 0; lod--)
			{
				nodeIDOffsetLOD[lod * 4] = nodeIdOffset;
				nodeIdOffset += (int) (worldLODParams[lod].z * worldLODParams[lod].z);
			}

			_computeShader.SetInts(ShaderConstants.NodeIDOffsetOfLOD_ID, nodeIDOffsetLOD);
		}

		private void ClearBufferCounter()
		{
			_commandBuffer.SetComputeBufferCounterValue(_maxLODNodeList, (uint) _maxLODNodeList.count);
			_commandBuffer.SetComputeBufferCounterValue(_nodeListA, 0);
			_commandBuffer.SetComputeBufferCounterValue(_nodeListB, 0);
			_commandBuffer.SetComputeBufferCounterValue(_finalNodeListBuffer, 0);
			_commandBuffer.SetComputeBufferCounterValue(_culledPatchBuffer, 0);
			_commandBuffer.SetComputeBufferCounterValue(_patchBoundsBuffer, 0);
		}

		private void UpdateCameraFrustumPlanes(Camera camera)
		{
			GeometryUtility.CalculateFrustumPlanes(camera, _cameraFrustumPlanes);
			for (var i = 0; i < _cameraFrustumPlanes.Length; i++)
			{
				var plane = _cameraFrustumPlanes[i];
				var nor = plane.normal;
				Vector4 v4 = new Vector4(nor.x, nor.y, nor.z, plane.distance);
				_cameraFrustumPlanesV4[i] = v4;
			}

			_computeShader.SetVectorArray(ShaderConstants.CameraFrustumPlanes_ID, _cameraFrustumPlanesV4);
		}

		private void LogPatchArgs()
		{
			var data = new uint[5];
			_patchIndirectArgs.GetData(data);
			Debug.Log(data[1]);
		}

		public void Dispatch()
		{
			var camera = Camera.main;

			//clear
			_commandBuffer.Clear();
			ClearBufferCounter();

			UpdateCameraFrustumPlanes(camera);

			if (_isNodeEvaluationCDirty)
			{
				_isNodeEvaluationCDirty = false;
				_commandBuffer.SetComputeVectorParam(_computeShader, ShaderConstants.NodeEvaluationC_ID,
					_nodeEvaluationC);
			}

			_commandBuffer.SetComputeVectorParam(_computeShader, ShaderConstants.CameraPositionWS_ID,
				camera.transform.position);
			_commandBuffer.SetComputeVectorParam(_computeShader, ShaderConstants.WorldSize_ID, _asset.worldSize);

			//四叉树分割计算得到初步的Patch列表
			_commandBuffer.CopyCounterValue(_maxLODNodeList, _indirectArgsBuffer, 0);
			ComputeBuffer consumeNodeList = _nodeListA;
			ComputeBuffer appendNodeList = _nodeListB;
			for (var lod = TerrainAsset.MAX_LOD; lod >= 0; lod--)
			{
				_commandBuffer.SetComputeIntParam(_computeShader, ShaderConstants.PassLOD_ID, lod);
				if (lod == TerrainAsset.MAX_LOD)
				{
					_commandBuffer.SetComputeBufferParam(_computeShader, _kernelOfTraverseQuadTree,
						ShaderConstants.ConsumeNodeList_ID, _maxLODNodeList);
				}
				else
				{
					_commandBuffer.SetComputeBufferParam(_computeShader, _kernelOfTraverseQuadTree,
						ShaderConstants.ConsumeNodeList_ID, consumeNodeList);
				}

				_commandBuffer.SetComputeBufferParam(_computeShader, _kernelOfTraverseQuadTree,
					ShaderConstants.AppendNodeList_ID, appendNodeList);
				_commandBuffer.DispatchCompute(_computeShader, _kernelOfTraverseQuadTree, _indirectArgsBuffer, 0);
				_commandBuffer.CopyCounterValue(appendNodeList, _indirectArgsBuffer, 0);
				var temp = consumeNodeList;
				consumeNodeList = appendNodeList;
				appendNodeList = temp;
			}

			//生成LodMap
			_commandBuffer.DispatchCompute(_computeShader, _kernelOfBuildLodMap, 20, 20, 1);


			//生成Patch
			_commandBuffer.CopyCounterValue(_finalNodeListBuffer, _indirectArgsBuffer, 0);
			_commandBuffer.DispatchCompute(_computeShader, _kernelOfBuildPatches, _indirectArgsBuffer, 0);
			_commandBuffer.CopyCounterValue(_culledPatchBuffer, _patchIndirectArgs, 4);
			if (isBoundsBufferOn)
			{
				_commandBuffer.CopyCounterValue(_patchBoundsBuffer, _patchBoundsIndirectArgs, 4);
			}

			UnityEngine.Graphics.ExecuteCommandBuffer(_commandBuffer);

			// this.LogPatchArgs();
		}


		public void Dispose()
		{
			_culledPatchBuffer.Dispose();
			_patchIndirectArgs.Dispose();
			_finalNodeListBuffer.Dispose();
			_maxLODNodeList.Dispose();
			_nodeListA.Dispose();
			_nodeListB.Dispose();
			_indirectArgsBuffer.Dispose();
			_patchBoundsBuffer.Dispose();
			_patchBoundsIndirectArgs.Dispose();
			_nodeDescriptors.Dispose();
		}
	}
}