#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <windows.h>

#include <array>
#include <cwchar>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\SMPlayerFlutter.SingleInstance";
constexpr ULONG_PTR kOpenExternalArgumentsCopyDataType = 0x534D504F;
constexpr wchar_t kWindowsAppUserModelId[] = L"com.seaky.simplemelodyplayer";
constexpr wchar_t kAudioProgId[] = L"SMPlayerFlutter.Audio";
constexpr wchar_t kRegisteredApplicationName[] = L"SMPlayer";
constexpr std::array<const wchar_t*, 11> kAudioExtensions = {
    L".mp3", L".flac", L".wma", L".alac", L".aiff", L".ape",
    L".aac", L".m4a", L".wav", L".ogg",  L".opus",
};

std::wstring QuoteWindowsArgument(const std::wstring& value) {
  std::wstring quoted = L"\"";
  unsigned int pending_backslashes = 0;
  for (wchar_t character : value) {
    if (character == L'\\') {
      pending_backslashes += 1;
      continue;
    }
    if (character == L'"') {
      quoted.append(pending_backslashes * 2 + 1, L'\\');
      quoted.push_back(character);
      pending_backslashes = 0;
      continue;
    }
    quoted.append(pending_backslashes, L'\\');
    quoted.push_back(character);
    pending_backslashes = 0;
  }
  quoted.append(pending_backslashes * 2, L'\\');
  quoted.push_back(L'"');
  return quoted;
}

void SetRegistryStringValue(HKEY key, const wchar_t* value_name,
                            const std::wstring& value) {
  ::RegSetValueExW(
      key, value_name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(value.c_str()),
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

std::wstring CurrentExecutablePath() {
  std::wstring buffer(MAX_PATH, L'\0');
  DWORD length = ::GetModuleFileNameW(nullptr, buffer.data(),
                                      static_cast<DWORD>(buffer.size()));
  while (length == buffer.size()) {
    buffer.resize(buffer.size() * 2);
    length = ::GetModuleFileNameW(nullptr, buffer.data(),
                                  static_cast<DWORD>(buffer.size()));
  }
  buffer.resize(length);
  return buffer;
}

void RegisterWindowsShellIntegrations() {
  const std::wstring executable_path = CurrentExecutablePath();
  if (executable_path.empty()) {
    return;
  }

  HKEY app_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                        L"Software\\Classes\\Applications\\smplayer_flutter.exe",
                        0, nullptr, 0, KEY_WRITE, nullptr, &app_key,
                        nullptr) == ERROR_SUCCESS) {
    SetRegistryStringValue(app_key, nullptr, L"Simple Melody Player");
    SetRegistryStringValue(app_key, L"FriendlyAppName", L"Simple Melody Player");
    HKEY app_command_key = nullptr;
    if (::RegCreateKeyExW(app_key, L"shell\\open\\command", 0, nullptr, 0,
                          KEY_WRITE, nullptr, &app_command_key,
                          nullptr) == ERROR_SUCCESS) {
      const std::wstring command =
          QuoteWindowsArgument(executable_path) + L" \"%1\"";
      SetRegistryStringValue(app_command_key, nullptr, command);
      ::RegCloseKey(app_command_key);
    }
    ::RegCloseKey(app_key);
  }

  HKEY capabilities_key = nullptr;
  if (::RegCreateKeyExW(
          HKEY_CURRENT_USER,
          L"Software\\Classes\\Applications\\smplayer_flutter.exe\\Capabilities",
          0, nullptr, 0, KEY_WRITE, nullptr, &capabilities_key,
          nullptr) == ERROR_SUCCESS) {
    SetRegistryStringValue(capabilities_key, L"ApplicationName",
                           L"Simple Melody Player");
    SetRegistryStringValue(capabilities_key, L"ApplicationDescription",
                           L"Simple Melody Player audio file");
    HKEY associations_key = nullptr;
    if (::RegCreateKeyExW(capabilities_key, L"FileAssociations", 0, nullptr, 0,
                          KEY_WRITE, nullptr, &associations_key,
                          nullptr) == ERROR_SUCCESS) {
      for (const wchar_t* extension : kAudioExtensions) {
        SetRegistryStringValue(associations_key, extension, kAudioProgId);
      }
      ::RegCloseKey(associations_key);
    }
    ::RegCloseKey(capabilities_key);
  }

  HKEY registered_applications_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                        L"Software\\RegisteredApplications", 0, nullptr, 0,
                        KEY_WRITE, nullptr, &registered_applications_key,
                        nullptr) == ERROR_SUCCESS) {
    SetRegistryStringValue(
        registered_applications_key, kRegisteredApplicationName,
        L"Software\\Classes\\Applications\\smplayer_flutter.exe\\Capabilities");
    ::RegCloseKey(registered_applications_key);
  }

  HKEY audio_prog_id_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER,
                        L"Software\\Classes\\SMPlayerFlutter.Audio", 0,
                        nullptr, 0, KEY_WRITE, nullptr, &audio_prog_id_key,
                        nullptr) == ERROR_SUCCESS) {
    SetRegistryStringValue(audio_prog_id_key, nullptr,
                           L"Simple Melody Player audio file");
    SetRegistryStringValue(audio_prog_id_key, L"FriendlyTypeName",
                           L"Simple Melody Player audio file");
    HKEY icon_key = nullptr;
    if (::RegCreateKeyExW(audio_prog_id_key, L"DefaultIcon", 0, nullptr, 0,
                          KEY_WRITE, nullptr, &icon_key,
                          nullptr) == ERROR_SUCCESS) {
      SetRegistryStringValue(icon_key, nullptr, executable_path);
      ::RegCloseKey(icon_key);
    }
    HKEY audio_command_key = nullptr;
    if (::RegCreateKeyExW(audio_prog_id_key, L"shell\\open\\command", 0,
                          nullptr, 0, KEY_WRITE, nullptr, &audio_command_key,
                          nullptr) == ERROR_SUCCESS) {
      const std::wstring command =
          QuoteWindowsArgument(executable_path) + L" \"%1\"";
      SetRegistryStringValue(audio_command_key, nullptr, command);
      ::RegCloseKey(audio_command_key);
    }
    ::RegCloseKey(audio_prog_id_key);
  }

  for (const wchar_t* extension : kAudioExtensions) {
    const std::wstring extension_key_path =
        std::wstring(L"Software\\Classes\\") + extension;
    HKEY extension_key = nullptr;
    if (::RegCreateKeyExW(HKEY_CURRENT_USER, extension_key_path.c_str(), 0,
                          nullptr, 0, KEY_WRITE, nullptr, &extension_key,
                          nullptr) == ERROR_SUCCESS) {
      SetRegistryStringValue(extension_key, L"PerceivedType", L"audio");
      HKEY open_with_key = nullptr;
      if (::RegCreateKeyExW(extension_key, L"OpenWithProgids", 0, nullptr, 0,
                            KEY_WRITE, nullptr, &open_with_key,
                            nullptr) == ERROR_SUCCESS) {
        ::RegSetValueExW(open_with_key, kAudioProgId, 0, REG_NONE, nullptr, 0);
        ::RegCloseKey(open_with_key);
      }
      ::RegCloseKey(extension_key);
    }
  }

  HKEY protocol_key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\smplayer", 0,
                        nullptr, 0, KEY_WRITE, nullptr, &protocol_key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }
  SetRegistryStringValue(protocol_key, nullptr, L"URL:SMPlayer Protocol");
  SetRegistryStringValue(protocol_key, L"URL Protocol", L"");

  HKEY icon_key = nullptr;
  if (::RegCreateKeyExW(protocol_key, L"DefaultIcon", 0, nullptr, 0, KEY_WRITE,
                        nullptr, &icon_key, nullptr) == ERROR_SUCCESS) {
    SetRegistryStringValue(icon_key, nullptr, executable_path);
    ::RegCloseKey(icon_key);
  }

  HKEY command_key = nullptr;
  if (::RegCreateKeyExW(protocol_key, L"shell\\open\\command", 0, nullptr, 0,
                        KEY_WRITE, nullptr, &command_key,
                        nullptr) == ERROR_SUCCESS) {
    const std::wstring command =
        QuoteWindowsArgument(executable_path) + L" \"%1\"";
    SetRegistryStringValue(command_key, nullptr, command);
    ::RegCloseKey(command_key);
  }

  ::RegCloseKey(protocol_key);
  ::SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
}

bool ForwardCommandLineToExistingInstance() {
  HWND target_window = nullptr;
  for (int attempt = 0; attempt < 20 && target_window == nullptr; attempt += 1) {
    target_window = ::FindWindowW(kWindowClassName, nullptr);
    if (target_window == nullptr) {
      ::Sleep(50);
    }
  }
  if (target_window == nullptr) {
    return false;
  }

  const wchar_t* command_line = ::GetCommandLineW();
  COPYDATASTRUCT copy_data{};
  copy_data.dwData = kOpenExternalArgumentsCopyDataType;
  copy_data.cbData =
      static_cast<DWORD>((wcslen(command_line) + 1) * sizeof(wchar_t));
  copy_data.lpData = const_cast<wchar_t*>(command_line);
  ::SendMessageW(target_window, WM_COPYDATA, 0,
                 reinterpret_cast<LPARAM>(&copy_data));
  if (::IsIconic(target_window)) {
    ::ShowWindow(target_window, SW_RESTORE);
  }
  ::SetForegroundWindow(target_window);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  ::SetCurrentProcessExplicitAppUserModelID(kWindowsAppUserModelId);

  HANDLE single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS &&
      ForwardCommandLineToExistingInstance()) {
    ::CloseHandle(single_instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  RegisterWindowsShellIntegrations();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Simple Melody Player", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr) {
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
