#include "flutter_window.h"

#include <optional>
#include <shlobj.h>
#include <string>
#include <variant>
#include <vector>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr int kHotKeyPlayPause = 5001;
constexpr int kHotKeyPrevious = 5002;
constexpr int kHotKeyNext = 5003;
constexpr int kHotKeyStop = 5004;

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  int target_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  int converted_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), utf16_string.data(),
      target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterDesktopFeatureChannel();
  RegisterGlobalMediaHotkeys();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterDesktopFeatureChannel() {
  desktop_feature_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "smplayer_flutter/desktop_features",
          &flutter::StandardMethodCodec::GetInstance());
  desktop_feature_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "setRecentDocuments") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<std::vector<flutter::EncodableValue>>(call.arguments());
        if (!arguments) {
          result->Error("invalid_arguments",
                        "setRecentDocuments expects a string list.");
          return;
        }

        for (auto iterator = arguments->rbegin(); iterator != arguments->rend();
             ++iterator) {
          const auto* file_path = std::get_if<std::string>(&*iterator);
          if (!file_path || file_path->empty()) {
            continue;
          }
          const std::wstring utf16_path = Utf16FromUtf8(*file_path);
          if (!utf16_path.empty()) {
            ::SHAddToRecentDocs(SHARD_PATHW, utf16_path.c_str());
          }
        }

        result->Success();
      });
}

void FlutterWindow::RegisterGlobalMediaHotkeys() {
  HWND window_handle = GetHandle();
  ::RegisterHotKey(window_handle, kHotKeyPlayPause, 0, VK_MEDIA_PLAY_PAUSE);
  ::RegisterHotKey(window_handle, kHotKeyPrevious, 0, VK_MEDIA_PREV_TRACK);
  ::RegisterHotKey(window_handle, kHotKeyNext, 0, VK_MEDIA_NEXT_TRACK);
  ::RegisterHotKey(window_handle, kHotKeyStop, 0, VK_MEDIA_STOP);
}

void FlutterWindow::UnregisterGlobalMediaHotkeys() {
  HWND window_handle = GetHandle();
  ::UnregisterHotKey(window_handle, kHotKeyPlayPause);
  ::UnregisterHotKey(window_handle, kHotKeyPrevious);
  ::UnregisterHotKey(window_handle, kHotKeyNext);
  ::UnregisterHotKey(window_handle, kHotKeyStop);
}

void FlutterWindow::SendDesktopCommand(const std::string& command) {
  if (!desktop_feature_channel_) {
    return;
  }
  desktop_feature_channel_->InvokeMethod(
      "desktopCommand", std::make_unique<flutter::EncodableValue>(command));
}

void FlutterWindow::OnDestroy() {
  UnregisterGlobalMediaHotkeys();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_HOTKEY:
      switch (wparam) {
        case kHotKeyPlayPause:
          SendDesktopCommand("play-pause");
          return 0;
        case kHotKeyPrevious:
          SendDesktopCommand("previous");
          return 0;
        case kHotKeyNext:
          SendDesktopCommand("next");
          return 0;
        case kHotKeyStop:
          SendDesktopCommand("stop");
          return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
