#include "../dxvk/dxvk_include.h"

#include "d3d9_vr.h"

#include "d3d9_include.h"
#include "d3d9_surface.h"

#include "d3d9_device.h"

namespace dxvk {

class D3D9VR final : public ComObjectClamp<IDirect3DVR9>
{
public:
  D3D9VR(IDirect3DDevice9* pDevice)
    : m_device(static_cast<D3D9DeviceEx*>(pDevice))
  {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject)
  {
    if (ppvObject == nullptr)
      return E_POINTER;

    *ppvObject = nullptr;

    if (riid == __uuidof(IUnknown) || riid == __uuidof(IDirect3DVR9)) {
      *ppvObject = ref(this);
      return S_OK;
    }

    Logger::warn("D3D9VR::QueryInterface: Unknown interface query");
    Logger::warn(str::format(riid));
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE CopySurfaceToVulkanImage(IDirect3DSurface9* pSurface, VkImage dst, int64_t format, uint32_t dstWidth, uint32_t dstHeight)
  {
    if (unlikely(pSurface == nullptr))
      return D3DERR_INVALIDCALL;

    D3D9Surface* surface = static_cast<D3D9Surface*>(pSurface);
    auto* tex = surface->GetCommonTexture();
    const auto& device = tex->Device();
    const auto& dxvkdev = device->GetDXVKDevice();
    DxvkImageCreateInfo info;
    info.type = VK_IMAGE_TYPE_2D;
    info.format = static_cast<VkFormat>(format);
    info.sampleCount = VK_SAMPLE_COUNT_1_BIT;
    info.extent = { dstWidth, dstHeight, 1 };
    info.numLayers = 1;
    info.mipLevels = 1;
    info.usage = VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    info.stages = VK_PIPELINE_STAGE_TRANSFER_BIT;
    info.access = VK_ACCESS_TRANSFER_WRITE_BIT;
    info.tiling = VK_IMAGE_TILING_OPTIMAL;
    info.layout = VK_IMAGE_LAYOUT_UNDEFINED;
    info.shared = VK_FALSE;
    info.viewFormats = reinterpret_cast<VkFormat*>(&format);
    info.viewFormatCount = 1;

    auto dstImg = Rc(new DxvkImage(device->GetDXVKDevice().ptr(), info, dst, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));
    return device->CopyTextureToVkImage(tex, dstImg);
  }

  HRESULT STDMETHODCALLTYPE GetVRDesc(IDirect3DSurface9* pSurface,
                                      D3D9_TEXTURE_VR_DESC* pDesc)
  {
    if (unlikely(pSurface == nullptr || pDesc == nullptr))
      return D3DERR_INVALIDCALL;

    D3D9Surface* surface = static_cast<D3D9Surface*>(pSurface);

    const auto* tex = surface->GetCommonTexture();

    const auto& desc = tex->Desc();
    const auto& image = tex->GetImage();
    const auto& device = tex->Device()->GetDXVKDevice();

    // I don't know why the image randomly is a uint64_t in OpenVR.
    pDesc->Image = uint64_t(image->handle());
    pDesc->Device = device->handle();
    pDesc->PhysicalDevice = device->adapter()->handle();
    pDesc->Instance = device->instance()->handle();
    pDesc->Queue = device->queues().graphics.queueHandle;
    pDesc->QueueFamilyIndex = device->queues().graphics.queueFamily;

    pDesc->Width = desc->Width;
    pDesc->Height = desc->Height;
    pDesc->Format = tex->GetFormatMapping().FormatColor;
    pDesc->SampleCount = uint32_t(image->info().sampleCount);

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE TransferSurfaceForVR(IDirect3DSurface9* pSurface)
  {
    if (unlikely(pSurface == nullptr))
      return D3DERR_INVALIDCALL;

    auto* tex = static_cast<D3D9Surface*>(pSurface)->GetCommonTexture();
    const auto& image = tex->GetImage();

    VkImageSubresourceRange subresources = { VK_IMAGE_ASPECT_COLOR_BIT,
                                             0,
                                             image->info().mipLevels,
                                             0,
                                             image->info().numLayers };

    m_device->TransformImage(tex,
                             &subresources,
                             image->info().layout,
                             VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE LockDevice()
  {
    m_lock = m_device->LockDevice();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE UnlockDevice()
  {
    m_lock = D3D9DeviceLock();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE WaitDeviceIdle(BOOL flush)
  {
    if (flush) {
      m_device->Flush();
      m_device->SynchronizeCsThread(DxvkCsThread::SynchronizeAll);
    }
    m_device->GetDXVKDevice()->waitForIdle();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE WaitGraphicsQueueIdle(BOOL flush)
  {
    if (flush) {
      m_device->Flush();
      m_device->SynchronizeCsThread(DxvkCsThread::SynchronizeAll);
    }
    auto device = m_device->GetDXVKDevice();
    device->vkd()->vkQueueWaitIdle(device->queues().graphics.queueHandle);
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE BeginVRSubmit()
  {
    // m_device->Flush();
    m_device->SynchronizeCsThread(DxvkCsThread::SynchronizeAll);
    m_device->GetDXVKDevice()->lockSubmission();

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE EndVRSubmit()
  {
    m_device->GetDXVKDevice()->unlockSubmission();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE Flush()
  {
    m_device->Flush();
    m_device->SynchronizeCsThread(DxvkCsThread::SynchronizeAll);
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE LockSubmissionQueue()
  {
    m_device->GetDXVKDevice()->lockSubmission();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE UnlockSubmissionQueue()
  {
    m_device->GetDXVKDevice()->unlockSubmission();
    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE
  GetOXRVkDeviceDesc(OXR_VK_DEVICE_DESC* vkDeviceDescOut)
  {
    if (unlikely(vkDeviceDescOut == nullptr))
      return D3DERR_INVALIDCALL;

    auto device = m_device->GetDXVKDevice();

    vkDeviceDescOut->Device = device->handle();
    vkDeviceDescOut->PhysicalDevice = device->adapter()->handle();
    vkDeviceDescOut->Instance = device->instance()->handle();
    vkDeviceDescOut->QueueIndex = device->queues().graphics.queueIndex;
    vkDeviceDescOut->QueueFamilyIndex = device->queues().graphics.queueFamily;

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE ImportFence(HANDLE handle, uint64_t value)
  {
    const DxvkFenceCreateInfo fenceInfo = { value, VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D11_FENCE_BIT, handle };
    m_fence = m_device->GetDXVKDevice()->createFence(fenceInfo);

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE SignalFence(uint64_t value)
  {
      m_fence->signal(value);
      return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE GetShaderHash(IDirect3DVertexShader9 *d3dShader, char** out)
  {
    D3D9Shader<IDirect3DVertexShader9>* shader = reinterpret_cast<D3D9Shader<IDirect3DVertexShader9>*>(d3dShader);
    D3D9CommonShader const* common = shader->GetCommonShader();
    Rc<DxvkShader> dxvkShader = common->GetShader();

    const auto shaderKey = dxvkShader->getShaderKey().toString();
    memcpy(out, shaderKey.c_str(), shaderKey.size());

    return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE PatchSPIRVToVertexShader(IDirect3DVertexShader9 *d3dShader, const uint32_t* data, uint32_t size)
  {
      D3D9Shader<IDirect3DVertexShader9>* shader = reinterpret_cast<D3D9Shader<IDirect3DVertexShader9>*>(d3dShader);
      D3D9CommonShader const* common = shader->GetCommonShader();
      Rc<DxvkShader> dxvkShader = common->GetShader();
  
      SpirvCodeBuffer codeBuffer(size, data);
      DxvkShaderCreateInfo info = dxvkShader->info();
      auto codeBuf = dxvkShader->getRawCode();

      // DXVK shaders copy the binding info into a more clever container
      // We need to dig it out here and pass it into the constructor again in a DxvkBindingInfo array
      auto bindings = dxvkShader->getBindings();
      DxvkBindingInfo* bindingsCopy;

	  if (info.bindingCount > 0) {
        bindingsCopy = reinterpret_cast<DxvkBindingInfo*>(malloc(sizeof(DxvkBindingInfo) * info.bindingCount));

        for (int i = 0; i < info.bindingCount; ++i)
        {
            bindingsCopy[i] = bindings.getBinding(DxvkDescriptorSets::VsAll, i);
        }

        info.bindings = bindingsCopy;
	  }

      *dxvkShader.ptr_mut() = DxvkShader(info, std::move(codeBuffer));

      return D3D_OK;
  }

  HRESULT STDMETHODCALLTYPE CreateMultiViewRenderTarget(
          UINT                Width,
          UINT                Height,
          D3DFORMAT           Format,
          D3DMULTISAMPLE_TYPE MultiSample,
          DWORD               MultisampleQuality,
          BOOL                Lockable,
          IDirect3DSurface9** ppSurface,
          HANDLE*             pSharedHandle,
          UINT                Views) {
    InitReturnPtr(ppSurface);

    if (unlikely(ppSurface == nullptr))
      return D3DERR_INVALIDCALL;

    D3D9_COMMON_TEXTURE_DESC desc;
    desc.Width              = Width;
    desc.Height             = Height;
    desc.Depth              = 1;
    desc.ArraySize          = Views;
    desc.MipLevels          = 1;
    desc.Usage              = D3DUSAGE_RENDERTARGET;
    desc.Format             = EnumerateFormat(Format);
    desc.Pool               = D3DPOOL_DEFAULT;
    desc.Discard            = FALSE;
    desc.MultiSample        = MultiSample;
    desc.MultisampleQuality = MultisampleQuality;
    desc.IsBackBuffer       = FALSE;
    desc.IsAttachmentOnly   = TRUE;
    desc.IsLockable         = Lockable;

    return m_device->CreateRenderTargetFromDesc(&desc, ppSurface, pSharedHandle);
  }

  HRESULT STDMETHODCALLTYPE CreateMultiViewDepthStencilSurface(
          UINT                Width,
          UINT                Height,
          D3DFORMAT           Format,
          D3DMULTISAMPLE_TYPE MultiSample,
          DWORD               MultisampleQuality,
          BOOL                Discard,
          IDirect3DSurface9** ppSurface,
          HANDLE*             pSharedHandle,
          UINT                Views) {
    InitReturnPtr(ppSurface);

    if (unlikely(ppSurface == nullptr))
      return D3DERR_INVALIDCALL;

    D3D9_COMMON_TEXTURE_DESC desc;
    desc.Width              = Width;
    desc.Height             = Height;
    desc.Depth              = 1;
    desc.ArraySize          = Views;
    desc.MipLevels          = 1;
    desc.Usage              = D3DUSAGE_DEPTHSTENCIL;
    desc.Format             = EnumerateFormat(Format);
    desc.Pool               = D3DPOOL_DEFAULT;
    desc.Discard            = Discard;
    desc.MultiSample        = MultiSample;
    desc.MultisampleQuality = MultisampleQuality;
    desc.IsBackBuffer       = FALSE;
    desc.IsAttachmentOnly   = TRUE;
    desc.IsLockable         = IsLockableDepthStencilFormat(desc.Format);

    return m_device->CreateRenderTargetFromDesc(&desc, ppSurface, pSharedHandle);
  }

  HRESULT STDMETHODCALLTYPE CreateMultiViewTexture(UINT Width, UINT Height, UINT Levels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, IDirect3DTexture9** ppTexture, HANDLE* pSharedHandle, UINT Views)
  {
    D3D9_COMMON_TEXTURE_DESC desc;
    desc.Width              = Width;
    desc.Height             = Height;
    desc.Depth              = 1;
    desc.ArraySize          = Views;
    desc.MipLevels          = Levels;
    desc.Usage              = Usage;
    desc.Format             = EnumerateFormat(Format);
    desc.Pool               = Pool;
    desc.Discard            = FALSE;
    desc.MultiSample        = D3DMULTISAMPLE_NONE;
    desc.MultisampleQuality = 0;
    desc.IsBackBuffer       = FALSE;
    desc.IsAttachmentOnly   = FALSE;

    return m_device->CreateTextureFromDesc(&desc, ppTexture, pSharedHandle);
  }

  HRESULT STDMETHODCALLTYPE CopySurfaceLayers(IDirect3DSurface9 *srcSurface, IDirect3DSurface9** dsts, UINT layerCount)
  {
    // Assumes that `srcSurface` has `layerCount` layers and `dsts` contains `layerCount` of destination surfaces
    D3D9DeviceLock lock = m_device->LockDevice();
    D3D9Surface* src = static_cast<D3D9Surface*>(srcSurface);

    for(int i=0; i<layerCount; ++i) {
      D3D9Surface* dst = static_cast<D3D9Surface*>(dsts[i]);
      if (unlikely(src == nullptr || dst == nullptr))
        return D3DERR_INVALIDCALL;
      if (unlikely(src == dst))
        return D3DERR_INVALIDCALL;

      return m_device->StretchRectInternal(src, nullptr, dst, nullptr, D3DTEXF_NONE, i);
    }

    return D3D_OK;
  }

private:
  D3D9DeviceEx* m_device;
  D3D9DeviceLock m_lock;
  Rc<DxvkFence> m_fence;
};

}

HRESULT __stdcall Direct3DCreateVRImpl(IDirect3DDevice9* pDevice,
                                       IDirect3DVR9** pInterface)
{
  if (pInterface == nullptr)
    return D3DERR_INVALIDCALL;

  *pInterface = new dxvk::D3D9VR(pDevice);

  return D3D_OK;
}
