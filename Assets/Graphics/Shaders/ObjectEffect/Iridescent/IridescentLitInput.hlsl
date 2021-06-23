#ifndef  __IRIDESCENT_LIT_FORWARD_PASS__
#define __IRIDESCENT_LIT_FORWARD_PASS__

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/core.hlsl"
//universal/ShaderLibrary/core.hlsl  需要在 CommonMaterial 上面 不然会存在 define 和 重定义 的问题
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

struct InputDataAdvanced
{
};

#endif
