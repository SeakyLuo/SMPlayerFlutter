#include "directory_picker.h"

#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>
#include <string>
#include <thread>

#include "utils.h"

namespace {
struct DirectoryPickerResult {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> reply;
  HRESULT status = S_OK;
  std::string path;
};

std::wstring Argument(const flutter::EncodableMap& arguments,
                      const char* name) {
  const auto entry = arguments.find(flutter::EncodableValue(name));
  if (entry == arguments.end()) return {};
  const auto& value = std::get<std::string>(entry->second);
  const int length = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1,
                                        nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, wide.data(), length);
  wide.resize(length - 1);
  return wide;
}

HRESULT ShowDirectoryPicker(HWND owner,
                            const flutter::EncodableMap& arguments,
                            std::string& selected_path) {
  Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
  HRESULT status = CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                                    CLSCTX_INPROC_SERVER,
                                    IID_PPV_ARGS(&dialog));
  if (FAILED(status)) return status;
  DWORD options;
  status = dialog->GetOptions(&options);
  if (FAILED(status)) return status;
  status = dialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM |
                              FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR);
  if (FAILED(status)) return status;
  const auto title = Argument(arguments, "title");
  if (!title.empty()) {
    status = dialog->SetTitle(title.c_str());
    if (FAILED(status)) return status;
  }
  const auto button = Argument(arguments, "buttonLabel");
  if (!button.empty()) {
    status = dialog->SetOkButtonLabel(button.c_str());
    if (FAILED(status)) return status;
  }
  const auto initial_path = Argument(arguments, "defaultPath");
  Microsoft::WRL::ComPtr<IShellItem> folder;
  if (initial_path.empty()) {
    status = SHGetKnownFolderItem(FOLDERID_Music, KF_FLAG_DEFAULT, nullptr,
                                  IID_PPV_ARGS(&folder));
  } else {
    status = SHCreateItemFromParsingName(initial_path.c_str(), nullptr,
                                         IID_PPV_ARGS(&folder));
  }
  // Like Electron, an unavailable initial directory must not prevent picking
  // its replacement (for example, after moving the library or unplugging it).
  if (SUCCEEDED(status)) {
    status = dialog->SetFolder(folder.Get());
    if (FAILED(status)) return status;
  }
  status = dialog->Show(owner);
  if (FAILED(status)) return status;
  Microsoft::WRL::ComPtr<IShellItem> selection;
  status = dialog->GetResult(&selection);
  if (FAILED(status)) return status;
  PWSTR path = nullptr;
  status = selection->GetDisplayName(SIGDN_FILESYSPATH, &path);
  if (FAILED(status)) return status;
  selected_path = Utf8FromUtf16(path);
  CoTaskMemFree(path);
  return S_OK;
}
}  // namespace

void PickDirectory(
    HWND owner, const flutter::EncodableMap& arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // The runner uses MTA; shell dialogs require their own STA thread.
  std::thread([owner, arguments, reply = std::move(result)]() mutable {
    auto response = std::make_unique<DirectoryPickerResult>();
    response->reply = std::move(reply);
    response->status = CoInitializeEx(
        nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (SUCCEEDED(response->status)) {
      response->status = ShowDirectoryPicker(owner, arguments, response->path);
      CoUninitialize();
    }
    // Deliver Flutter's reply on the platform thread, never the dialog thread.
    if (PostMessageW(owner, kDirectoryPickerCompleted, 0,
                     reinterpret_cast<LPARAM>(response.get()))) {
      response.release();
    }
  }).detach();
}

void CompleteDirectoryPicker(LPARAM payload) {
  std::unique_ptr<DirectoryPickerResult> response(
      reinterpret_cast<DirectoryPickerResult*>(payload));
  if (response->status == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    response->reply->Success();
  } else if (FAILED(response->status)) {
    response->reply->Error("directory_picker_failed",
                           "Unable to select a directory.");
  } else {
    response->reply->Success(flutter::EncodableValue(response->path));
  }
}
