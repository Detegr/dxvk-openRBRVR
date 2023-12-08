#include "dxvk_instance.h"
#include "dxvk_openxr.h"

#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wnon-virtual-dtor"
#endif

using openRBRVR_Exec = int64_t (*)(uint64_t, uint64_t);

namespace dxvk {
  
  DxvkXrProvider DxvkXrProvider::s_instance;

  DxvkXrProvider:: DxvkXrProvider() { }

  DxvkXrProvider::~DxvkXrProvider() { }

  openRBRVR_Exec g_openRBRVR_exec;

  std::string_view DxvkXrProvider::getName() {
    return "OpenXR";
  }
  
  
  DxvkNameSet DxvkXrProvider::getInstanceExtensions() {
    std::lock_guard<dxvk::mutex> lock(m_mutex);
    return m_insExtensions;
  }


  DxvkNameSet DxvkXrProvider::getDeviceExtensions(uint32_t adapterId) {
    std::lock_guard<dxvk::mutex> lock(m_mutex);
    return m_devExtensions;
  }


  void DxvkXrProvider::initInstanceExtensions() {
    std::lock_guard<dxvk::mutex> lock(m_mutex);

    if (!m_openrbrvr)
        m_openrbrvr = this->loadLibrary();

    if (!m_openrbrvr || m_initializedInsExt)
      return;

    if (!this->loadFunctions()) {
      this->shutdown();
      return;
    }

    m_insExtensions = this->queryInstanceExtensions();
    m_initializedInsExt = true;
  }


  bool DxvkXrProvider::loadFunctions() {
    g_openRBRVR_exec = reinterpret_cast<openRBRVR_Exec>(GetProcAddress(m_openrbrvr, "openRBRVR_Exec"));
    return g_openRBRVR_exec != nullptr;
  }


  void DxvkXrProvider::initDeviceExtensions(const DxvkInstance* instance) {
    std::lock_guard<dxvk::mutex> lock(m_mutex);

    if (m_initializedDevExt)
      return;
    
    m_devExtensions = this->queryDeviceExtensions();
    m_initializedDevExt = true;

    this->shutdown();
  }


  DxvkNameSet DxvkXrProvider::queryInstanceExtensions() const {
    auto set = DxvkNameSet();
    set.add(VK_KHR_SURFACE_EXTENSION_NAME);
    set.add(VK_KHR_WIN32_SURFACE_EXTENSION_NAME);

    auto extensionList = (const char*)g_openRBRVR_exec(0x4, 0);
    if(extensionList) {
        auto exts = parseExtensionList(extensionList);
        set.merge(exts);
    }

    return set;
  }
  
  
  DxvkNameSet DxvkXrProvider::queryDeviceExtensions() const {
    auto set = DxvkNameSet();
    set.add(VK_KHR_SWAPCHAIN_EXTENSION_NAME);

    auto extensionList = (const char*)g_openRBRVR_exec(0x8, 0);
    if(extensionList) {
        auto exts = parseExtensionList(extensionList);
        set.merge(exts);
    }

    return set;
  }

  
  DxvkNameSet DxvkXrProvider::parseExtensionList(const std::string& str) const {
    DxvkNameSet result;
    
    std::stringstream strstream(str);
    std::string       section;
    
    while (std::getline(strstream, section, ' '))
      result.add(section.c_str());
    
    return result;
  }
  
  
  void DxvkXrProvider::shutdown() {
  }


  HMODULE DxvkXrProvider::loadLibrary() {
      return GetModuleHandle("Plugins\\openRBRVR.dll");
  }


  void DxvkXrProvider::freeLibrary() {
  }

  
  void* DxvkXrProvider::getSym(const char* sym) {
      return nullptr;
  }
}
