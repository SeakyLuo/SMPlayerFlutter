#include "application_data_path.h"

#include <windows.h>
#include <appmodel.h>
#include <roapi.h>
#include <string>
#include <winrt/Windows.Storage.h>
#include <winrt/base.h>

void GetApplicationDataPath(
    flutter::MethodResult<flutter::EncodableValue>& result) {
#ifdef _DEBUG
  // The sparse development identity enables Windows APIs, but development
  // builds must retain the library selected before that identity was added.
  result.Success(flutter::EncodableValue());
  return;
#else
  UINT32 length = 0;
  const LONG status = GetCurrentPackageFullName(&length, nullptr);
  if (status == APPMODEL_ERROR_NO_PACKAGE) {
    result.Success(flutter::EncodableValue());
    return;
  }
  if (status != ERROR_INSUFFICIENT_BUFFER) {
    result.Error("package_identity_error", std::to_string(status));
    return;
  }
  const HRESULT initialized = RoInitialize(RO_INIT_MULTITHREADED);
  if (FAILED(initialized)) {
    result.Error("application_data_runtime_error", std::to_string(initialized));
    return;
  }
  try {
    const auto path =
        winrt::Windows::Storage::ApplicationData::Current().LocalFolder().Path();
    result.Success(flutter::EncodableValue(winrt::to_string(path)));
  } catch (const winrt::hresult_error& error) {
    result.Error("application_data_path_error", winrt::to_string(error.message()));
  }
  RoUninitialize();
#endif
}
