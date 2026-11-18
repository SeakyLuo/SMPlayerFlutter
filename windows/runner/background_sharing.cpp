#include "background_sharing.h"
#include "application_data_path.h"
#include "utils.h"

#include <windows.h>
#include <appmodel.h>
#include <shellapi.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.ApplicationModel.Activation.h>
#include <winrt/Windows.Foundation.h>
#include <algorithm>
#include <future>
#include <cstdlib>
#include <cwchar>
#include <vector>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunName[] = L"SMPlayerBackgroundSharing";
constexpr wchar_t kTaskId[] = L"SMPlayerBackgroundSharing";
HANDLE worker_process = nullptr;

bool IsPackaged() {
  UINT32 length = 0;
  const LONG status = GetCurrentPackageFullName(&length, nullptr);
  if (status == APPMODEL_ERROR_NO_PACKAGE) return false;
  if (status != ERROR_INSUFFICIENT_BUFFER) throw std::runtime_error("Cannot read package identity");
  return true;
}

void SetLoginEnabled(bool enabled) {
  if (IsPackaged()) {
    // Keep the UI's STA apartment intact. WinRT blocking waits must run in MTA.
    std::async(std::launch::async, [enabled] {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
      try {
        const auto task = winrt::Windows::ApplicationModel::StartupTask::GetAsync(kTaskId).get();
        if (!enabled) task.Disable();
        else {
          const auto state = task.RequestEnableAsync().get();
          using winrt::Windows::ApplicationModel::StartupTaskState;
          if (state != StartupTaskState::Enabled && state != StartupTaskState::EnabledByPolicy) {
            throw std::runtime_error("background_approval_required");
          }
        }
      } catch (...) {
        winrt::uninit_apartment();
        throw;
      }
      winrt::uninit_apartment();
    }).get();
    return;
  }
  HKEY key = nullptr;
  const LONG opened = RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                                      KEY_SET_VALUE, nullptr, &key, nullptr);
  if (opened != ERROR_SUCCESS) throw std::runtime_error("Cannot open login startup settings");
  LONG result;
  if (enabled) {
    wchar_t path[32768];
    const DWORD length = GetModuleFileNameW(nullptr, path, 32768);
    if (length == 0 || length == 32768) { RegCloseKey(key); throw std::runtime_error("Cannot read executable path"); }
    const std::wstring command = L"\"" + std::wstring(path, length) + L"\" --sharing-worker";
    result = RegSetValueExW(key, kRunName, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    result = RegDeleteValueW(key, kRunName);
    if (result == ERROR_FILE_NOT_FOUND) result = ERROR_SUCCESS;
  }
  RegCloseKey(key);
  if (result != ERROR_SUCCESS) throw std::runtime_error("Cannot update login startup settings");
}
}

bool IsBackgroundSharingLaunch() {
  const auto arguments = GetCommandLineArguments();
  if (std::find(arguments.begin(), arguments.end(), "--sharing-worker") != arguments.end()) return true;
  if (!IsPackaged()) return false;
  const auto activation = winrt::Windows::ApplicationModel::AppInstance::GetActivatedEventArgs();
  return activation && activation.Kind() == winrt::Windows::ApplicationModel::Activation::ActivationKind::StartupTask;
}

int RunBackgroundSharingWorker() {
  // Remove debugger configuration inherited from the UI process before creating
  // an independent engine, which has no debugger to resume a paused isolate.
  std::vector<std::wstring> engine_variables;
  LPWCH environment = GetEnvironmentStringsW();
  for (const wchar_t* entry = environment; *entry; entry += wcslen(entry) + 1) {
    const std::wstring variable(entry, wcschr(entry, L'='));
    if (variable == L"FLUTTER_ENGINE_SWITCHES" ||
        variable.rfind(L"FLUTTER_ENGINE_SWITCH_", 0) == 0) {
      engine_variables.push_back(variable);
    }
  }
  FreeEnvironmentStringsW(environment);
  for (const auto& variable : engine_variables) {
    SetEnvironmentVariableW(variable.c_str(), nullptr);
    _wputenv_s(variable.c_str(), L"");
  }
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("backgroundSharingMain");
  flutter::FlutterEngine engine(project);
  if (!engine.Run()) return EXIT_FAILURE;
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(engine.GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
  Sqlite3FlutterLibsPluginRegisterWithRegistrar(engine.GetRegistrarForPlugin("Sqlite3FlutterLibsPlugin"));
  RegisterBackgroundSharingChannel(engine.messenger());
  auto desktop = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine.messenger(), "smplayer_flutter/desktop_features", &flutter::StandardMethodCodec::GetInstance());
  desktop->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "getApplicationDataPath") GetApplicationDataPath(*result);
    else result->NotImplemented();
  });
  MSG message;
  while (GetMessageW(&message, nullptr, 0, 0)) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  return EXIT_SUCCESS;
}

void RegisterBackgroundSharingChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "smplayer_flutter/background_sharing", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    try {
      if (call.method_name() == "supported") result->Success(flutter::EncodableValue(true));
      else if (call.method_name() == "openPlayer") {
        wchar_t path[32768];
        const DWORD length = GetModuleFileNameW(nullptr, path, 32768);
        if (length == 0 || length == 32768) throw std::runtime_error("Cannot read executable path");
        const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", path, nullptr, nullptr, SW_SHOWNORMAL));
        if (opened <= 32) throw std::runtime_error("player_open_failed");
        result->Success();
      }
      else if (call.method_name() == "start") {
        wchar_t path[32768];
        const DWORD length = GetModuleFileNameW(nullptr, path, 32768);
        if (length == 0 || length == 32768) throw std::runtime_error("Cannot read executable path");
        std::wstring command = L"\"" + std::wstring(path, length) + L"\" --sharing-worker";
        STARTUPINFOW startup = {};
        startup.cb = sizeof(startup);
        PROCESS_INFORMATION process = {};
        if (!CreateProcessW(path, command.data(), nullptr, nullptr, FALSE,
                            CREATE_NO_WINDOW | DETACHED_PROCESS, nullptr, nullptr, &startup, &process)) {
          throw std::runtime_error("Cannot launch sharing worker");
        }
        CloseHandle(process.hThread);
        if (worker_process != nullptr) CloseHandle(worker_process);
        worker_process = process.hProcess;
        result->Success();
      } else if (call.method_name() == "stop") {
        if (worker_process != nullptr) {
          if (WaitForSingleObject(worker_process, 0) == WAIT_TIMEOUT) {
            TerminateProcess(worker_process, 0);
            WaitForSingleObject(worker_process, INFINITE);
          }
          CloseHandle(worker_process);
          worker_process = nullptr;
        }
        result->Success();
      }
      else if (call.method_name() == "setLoginEnabled") {
        SetLoginEnabled(std::get<bool>(*call.arguments()));
        result->Success();
      } else if (call.method_name() == "openSettings") {
        ShellExecuteW(nullptr, L"open", L"ms-settings:startupapps", nullptr, nullptr, SW_SHOWNORMAL);
        result->Success();
      } else result->NotImplemented();
    } catch (const winrt::hresult_error& error) {
      result->Error("background_registration_failed", winrt::to_string(error.message()));
    } catch (const std::exception& error) {
      result->Error(error.what(), error.what());
    }
  });
}
