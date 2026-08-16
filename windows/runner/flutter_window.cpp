#include "flutter_window.h"

#include <chrono>
#include <dwmapi.h>
#include <optional>
#include <propkey.h>
#include <propvarutil.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <systemmediatransportcontrolsinterop.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cwchar>
#include <string>
#include <variant>
#include <vector>
#include <windows.h>
#include <windowsx.h>
#include <wrl/client.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {

constexpr int kHotKeyPlayPause = 5001;
constexpr int kHotKeyPrevious = 5002;
constexpr int kHotKeyNext = 5003;
constexpr int kHotKeyStop = 5004;
constexpr int kTaskbarButtonPrevious = 5101;
constexpr int kTaskbarButtonPlayPause = 5102;
constexpr int kTaskbarButtonNext = 5103;
constexpr wchar_t kWindowsAppUserModelId[] = L"com.seaky.simplemelodyplayer";
constexpr ULONG_PTR kOpenExternalArgumentsCopyDataType = 0x534D504F;
constexpr wchar_t kDesktopLyricsWindowClass[] = L"SMPlayerDesktopLyricsWindow";
constexpr wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif

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

bool EncodableBool(const flutter::EncodableMap& map, const char* key) {
  const auto iterator = map.find(flutter::EncodableValue(key));
  if (iterator == map.end()) {
    return false;
  }
  const auto* value = std::get_if<bool>(&iterator->second);
  return value != nullptr && *value;
}

int EncodableInt(const flutter::EncodableMap& map, const char* key,
                 int fallback) {
  const auto iterator = map.find(flutter::EncodableValue(key));
  if (iterator == map.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<int>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<int>(*value);
  }
  return fallback;
}

double EncodableDouble(const flutter::EncodableMap& map, const char* key,
                       double fallback) {
  const auto iterator = map.find(flutter::EncodableValue(key));
  if (iterator == map.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<double>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<double>(*value);
  }
  return fallback;
}

std::wstring EncodableString(const flutter::EncodableMap& map, const char* key) {
  const auto iterator = map.find(flutter::EncodableValue(key));
  if (iterator == map.end()) {
    return std::wstring();
  }
  const auto* value = std::get_if<std::string>(&iterator->second);
  return value == nullptr ? std::wstring() : Utf16FromUtf8(*value);
}

HICON CreateTaskbarGlyphIcon(const wchar_t* glyph, COLORREF color) {
  const int icon_width = ::GetSystemMetrics(SM_CXICON);
  const int icon_height = ::GetSystemMetrics(SM_CYICON);
  BITMAPV5HEADER bitmap_header = {};
  bitmap_header.bV5Size = sizeof(BITMAPV5HEADER);
  bitmap_header.bV5Width = icon_width;
  bitmap_header.bV5Height = -icon_height;
  bitmap_header.bV5Planes = 1;
  bitmap_header.bV5BitCount = 32;
  bitmap_header.bV5Compression = BI_BITFIELDS;
  bitmap_header.bV5RedMask = 0x00ff0000;
  bitmap_header.bV5GreenMask = 0x0000ff00;
  bitmap_header.bV5BlueMask = 0x000000ff;
  bitmap_header.bV5AlphaMask = 0xff000000;

  HDC screen_dc = ::GetDC(nullptr);
  void* bits = nullptr;
  HBITMAP color_bitmap = ::CreateDIBSection(
      screen_dc, reinterpret_cast<BITMAPINFO*>(&bitmap_header), DIB_RGB_COLORS,
      &bits, nullptr, 0);
  HDC memory_dc = ::CreateCompatibleDC(screen_dc);
  HGDIOBJ old_bitmap = ::SelectObject(memory_dc, color_bitmap);

  HFONT font = ::CreateFontW(
      -MulDiv(22, icon_height, 32), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
      L"Segoe MDL2 Assets");
  HGDIOBJ old_font = ::SelectObject(memory_dc, font);
  ::SetBkMode(memory_dc, TRANSPARENT);
  ::SetTextColor(memory_dc, RGB(255, 255, 255));
  RECT rect{0, 0, icon_width, icon_height};
  ::DrawTextW(memory_dc, glyph, -1, &rect,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  auto* pixels = static_cast<uint32_t*>(bits);
  const uint32_t blue = GetBValue(color);
  const uint32_t green = GetGValue(color);
  const uint32_t red = GetRValue(color);
  for (int index = 0; index < icon_width * icon_height; index += 1) {
    const uint32_t coverage = pixels[index] & 0xff;
    pixels[index] = coverage << 24 | red * coverage / 255 << 16 |
                    green * coverage / 255 << 8 | blue * coverage / 255;
  }

  ::SelectObject(memory_dc, old_font);
  ::DeleteObject(font);
  ::SelectObject(memory_dc, old_bitmap);
  ::DeleteDC(memory_dc);

  const int mask_stride = ((icon_width + 15) / 16) * 2;
  std::vector<unsigned char> mask_pixels(mask_stride * icon_height, 0);
  HBITMAP mask_bitmap = ::CreateBitmap(icon_width, icon_height, 1, 1,
                                       mask_pixels.data());
  ICONINFO icon_info = {};
  icon_info.fIcon = TRUE;
  icon_info.hbmColor = color_bitmap;
  icon_info.hbmMask = mask_bitmap;
  HICON icon = ::CreateIconIndirect(&icon_info);

  ::DeleteObject(mask_bitmap);
  ::DeleteObject(color_bitmap);
  ::ReleaseDC(nullptr, screen_dc);
  return icon;
}

COLORREF ColorFromHex(const std::wstring& value, COLORREF fallback) {
  if (value.length() != 7 || value[0] != L'#') {
    return fallback;
  }
  const int red = std::wcstol(value.substr(1, 2).c_str(), nullptr, 16);
  const int green = std::wcstol(value.substr(3, 2).c_str(), nullptr, 16);
  const int blue = std::wcstol(value.substr(5, 2).c_str(), nullptr, 16);
  return RGB(red, green, blue);
}

bool IsDarkModePreferred() {
  DWORD value = 1;
  DWORD value_size = sizeof(value);
  const LSTATUS result = ::RegGetValueW(
      HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
      kGetPreferredBrightnessRegValue, RRF_RT_REG_DWORD, nullptr, &value,
      &value_size);
  return result == ERROR_SUCCESS && value == 0;
}

RECT ResolveDesktopLyricsBounds(HWND owner, const std::wstring& raw_bounds) {
  RECT work_area;
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  int x = work_area.left + ((work_area.right - work_area.left) - 760) / 2;
  int y = work_area.bottom - 148 - 120;
  int width = 760;
  int height = 148;
  if (!raw_bounds.empty()) {
    int parsed_x = 0;
    int parsed_y = 0;
    int parsed_width = 0;
    int parsed_height = 0;
    if (::swscanf_s(raw_bounds.c_str(),
                    L"{\"x\":%d,\"y\":%d,\"width\":%d,\"height\":%d",
                    &parsed_x, &parsed_y, &parsed_width, &parsed_height) == 4 ||
        ::swscanf_s(raw_bounds.c_str(), L"%d,%d,%d,%d", &parsed_x, &parsed_y,
                    &parsed_width, &parsed_height) == 4) {
      x = parsed_x;
      y = parsed_y;
    }
  }
  return RECT{x, y, x + width, y + height};
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
  if (length == 0) {
    return std::wstring();
  }
  buffer.resize(length);
  return buffer;
}

std::wstring FileNameFromPath(const std::wstring& file_path) {
  const size_t separator = file_path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? file_path
                                         : file_path.substr(separator + 1);
}

std::wstring QuoteWindowsArgument(const std::wstring& value) {
  std::wstring escaped = L"\"";
  for (wchar_t character : value) {
    if (character == L'\\' || character == L'"') {
      escaped.push_back(L'\\');
    }
    escaped.push_back(character);
  }
  escaped.push_back(L'"');
  return escaped;
}

HRESULT SetShellLinkTitle(IShellLinkW* link, const std::wstring& title) {
  Microsoft::WRL::ComPtr<IPropertyStore> property_store;
  HRESULT result = link->QueryInterface(IID_PPV_ARGS(&property_store));
  if (FAILED(result)) {
    return result;
  }

  PROPVARIANT title_value;
  result = ::InitPropVariantFromString(title.c_str(), &title_value);
  if (FAILED(result)) {
    return result;
  }

  result = property_store->SetValue(PKEY_Title, title_value);
  ::PropVariantClear(&title_value);
  if (FAILED(result)) {
    return result;
  }

  return property_store->Commit();
}

HRESULT AddJumpListTask(IObjectCollection* collection,
                        const std::wstring& executable_path,
                        const std::wstring& file_path) {
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  HRESULT result =
      ::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&link));
  if (FAILED(result)) {
    return result;
  }

  result = link->SetPath(executable_path.c_str());
  if (FAILED(result)) {
    return result;
  }
  const std::wstring arguments = QuoteWindowsArgument(file_path);
  result = link->SetArguments(arguments.c_str());
  if (FAILED(result)) {
    return result;
  }
  result = link->SetDescription(file_path.c_str());
  if (FAILED(result)) {
    return result;
  }
  link->SetIconLocation(executable_path.c_str(), 0);

  result = SetShellLinkTitle(link.Get(), FileNameFromPath(file_path));
  if (FAILED(result)) {
    return result;
  }

  return collection->AddObject(link.Get());
}

winrt::Windows::Foundation::TimeSpan TimeSpanFromSeconds(double seconds) {
  return std::chrono::duration_cast<winrt::Windows::Foundation::TimeSpan>(
      std::chrono::duration<double>(std::max(0.0, seconds)));
}

HRESULT UpdateWindowsJumpList(const std::wstring& category_name,
                              const std::vector<std::wstring>& file_paths) {
  ::SHAddToRecentDocs(SHARD_PATHW, nullptr);
  for (auto iterator = file_paths.rbegin(); iterator != file_paths.rend();
       ++iterator) {
    ::SHAddToRecentDocs(SHARD_PATHW, iterator->c_str());
  }

  Microsoft::WRL::ComPtr<ICustomDestinationList> destination_list;
  HRESULT result =
      ::CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&destination_list));
  if (FAILED(result)) {
    return result;
  }

  destination_list->SetAppID(kWindowsAppUserModelId);

  UINT min_slots = 0;
  Microsoft::WRL::ComPtr<IObjectArray> removed_items;
  result = destination_list->BeginList(&min_slots, IID_PPV_ARGS(&removed_items));
  if (FAILED(result)) {
    return result;
  }

  if (!file_paths.empty()) {
    const std::wstring executable_path = CurrentExecutablePath();
    Microsoft::WRL::ComPtr<IObjectCollection> collection;
    result = ::CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&collection));
    if (FAILED(result)) {
      return result;
    }
    for (const std::wstring& file_path : file_paths) {
      result = AddJumpListTask(collection.Get(), executable_path, file_path);
      if (FAILED(result)) {
        return result;
      }
    }

    Microsoft::WRL::ComPtr<IObjectArray> tasks;
    result = collection.As(&tasks);
    if (FAILED(result)) {
      return result;
    }
    result = destination_list->AppendCategory(category_name.c_str(),
                                              tasks.Get());
    if (FAILED(result)) {
      return result;
    }
  }

  return destination_list->CommitList();
}

}  // namespace

struct WindowsMediaSessionState {
  winrt::Windows::Media::SystemMediaTransportControls controls{nullptr};
  winrt::event_token button_pressed_token{};
  winrt::event_token playback_position_changed_token{};
};

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
  taskbar_button_created_message_ =
      ::RegisterWindowMessageW(L"TaskbarButtonCreated");
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  native_splash_visible_ = true;
  ::ShowWindow(flutter_controller_->view()->GetNativeWindow(), SW_HIDE);
  this->Show();
  ::InvalidateRect(GetHandle(), nullptr, TRUE);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    DismissNativeSplash();
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
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "updateDesktopLyricsWindow") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments",
                          "updateDesktopLyricsWindow expects state.");
            return;
          }
          UpdateDesktopLyricsWindow(*arguments);
          result->Success();
          return;
        }

        if (call.method_name() == "setWindowControlsLight") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments",
                          "setWindowControlsLight expects state.");
            return;
          }
          ApplyWindowControlsLight(EncodableBool(*arguments, "light"));
          result->Success();
          return;
        }

        if (call.method_name() == "updateMediaSession") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments",
                          "updateMediaSession expects state.");
            return;
          }
          UpdateMediaSession(*arguments);
          result->Success();
          return;
        }

        if (call.method_name() == "dismissNativeSplash") {
          DismissNativeSplash();
          result->Success();
          return;
        }

        if (call.method_name() != "setRecentDocuments") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("invalid_arguments",
                        "setRecentDocuments expects a label and paths.");
          return;
        }
        const auto label_iterator =
            arguments->find(flutter::EncodableValue("label"));
        const auto paths_iterator =
            arguments->find(flutter::EncodableValue("paths"));
        const std::string& category_label =
            std::get<std::string>(label_iterator->second);
        const auto& recent_paths =
            std::get<std::vector<flutter::EncodableValue>>(
                paths_iterator->second);

        std::vector<std::wstring> file_paths;
        file_paths.reserve(recent_paths.size());
        for (const flutter::EncodableValue& argument : recent_paths) {
          const auto* file_path = std::get_if<std::string>(&argument);
          if (!file_path || file_path->empty()) {
            continue;
          }
          const std::wstring utf16_path = Utf16FromUtf8(*file_path);
          if (!utf16_path.empty()) {
            file_paths.push_back(utf16_path);
          }
        }

        const HRESULT update_result =
            UpdateWindowsJumpList(Utf16FromUtf8(category_label), file_paths);
        if (FAILED(update_result)) {
          result->Error("jump_list_update_failed",
                        "Failed to update Windows Jump List.");
          return;
        }

        result->Success();
      });
}

void FlutterWindow::RegisterGlobalMediaHotkeys() {
  hot_key_window_ = GetHandle();
  ::RegisterHotKey(hot_key_window_, kHotKeyPlayPause, 0, VK_MEDIA_PLAY_PAUSE);
  ::RegisterHotKey(hot_key_window_, kHotKeyPrevious, 0, VK_MEDIA_PREV_TRACK);
  ::RegisterHotKey(hot_key_window_, kHotKeyNext, 0, VK_MEDIA_NEXT_TRACK);
  ::RegisterHotKey(hot_key_window_, kHotKeyStop, 0, VK_MEDIA_STOP);
}

void FlutterWindow::UnregisterGlobalMediaHotkeys() {
  ::UnregisterHotKey(hot_key_window_, kHotKeyPlayPause);
  ::UnregisterHotKey(hot_key_window_, kHotKeyPrevious);
  ::UnregisterHotKey(hot_key_window_, kHotKeyNext);
  ::UnregisterHotKey(hot_key_window_, kHotKeyStop);
  hot_key_window_ = nullptr;
}

void FlutterWindow::EnsureTaskbarToolbar() {
  if (taskbar_buttons_added_) {
    return;
  }

  if (!taskbar_list_) {
    if (FAILED(::CoCreateInstance(CLSID_TaskbarList, nullptr,
                                  CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&taskbar_list_)))) {
      return;
    }
    if (FAILED(taskbar_list_->HrInit())) {
      taskbar_list_.Reset();
      return;
    }
  }

  const COLORREF icon_color =
      IsDarkModePreferred() ? RGB(245, 248, 252) : RGB(32, 38, 46);
  if (taskbar_previous_icon_ == nullptr) {
    taskbar_previous_icon_ = CreateTaskbarGlyphIcon(L"\xE100", icon_color);
  }
  if (taskbar_play_icon_ == nullptr) {
    taskbar_play_icon_ = CreateTaskbarGlyphIcon(L"\xE102", icon_color);
  }
  if (taskbar_pause_icon_ == nullptr) {
    taskbar_pause_icon_ = CreateTaskbarGlyphIcon(L"\xE103", icon_color);
  }
  if (taskbar_next_icon_ == nullptr) {
    taskbar_next_icon_ = CreateTaskbarGlyphIcon(L"\xE101", icon_color);
  }
  if (taskbar_previous_icon_ == nullptr || taskbar_play_icon_ == nullptr ||
      taskbar_pause_icon_ == nullptr || taskbar_next_icon_ == nullptr) {
    return;
  }

  THUMBBUTTON buttons[3] = {};
  buttons[0].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[0].iId = kTaskbarButtonPrevious;
  buttons[0].hIcon = taskbar_previous_icon_;
  buttons[0].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[0].szTip, L"Previous");

  buttons[1].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[1].iId = kTaskbarButtonPlayPause;
  buttons[1].hIcon = taskbar_play_icon_;
  buttons[1].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[1].szTip, L"Play");

  buttons[2].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[2].iId = kTaskbarButtonNext;
  buttons[2].hIcon = taskbar_next_icon_;
  buttons[2].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[2].szTip, L"Next");

  if (SUCCEEDED(taskbar_list_->ThumbBarAddButtons(GetHandle(), 3, buttons))) {
    taskbar_buttons_added_ = true;
  }
}

void FlutterWindow::UpdateTaskbarToolbar(bool active, bool playing) {
  taskbar_media_active_ = active;
  taskbar_media_playing_ = playing;
  EnsureTaskbarToolbar();
  if (!taskbar_buttons_added_ || !taskbar_list_) {
    return;
  }

  THUMBBUTTON buttons[3] = {};
  buttons[0].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[0].iId = kTaskbarButtonPrevious;
  buttons[0].hIcon = taskbar_previous_icon_;
  buttons[0].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[0].szTip, L"Previous");

  buttons[1].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[1].iId = kTaskbarButtonPlayPause;
  buttons[1].hIcon = playing ? taskbar_pause_icon_ : taskbar_play_icon_;
  buttons[1].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[1].szTip, playing ? L"Pause" : L"Play");

  buttons[2].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
  buttons[2].iId = kTaskbarButtonNext;
  buttons[2].hIcon = taskbar_next_icon_;
  buttons[2].dwFlags = THBF_ENABLED;
  wcscpy_s(buttons[2].szTip, L"Next");

  taskbar_list_->ThumbBarUpdateButtons(GetHandle(), 3, buttons);
}

void FlutterWindow::SendDesktopCommand(const std::string& command) {
  if (!desktop_feature_channel_) {
    return;
  }
  desktop_feature_channel_->InvokeMethod(
      "desktopCommand", std::make_unique<flutter::EncodableValue>(command));
}

void FlutterWindow::SendOpenExternalArguments(
    const std::vector<std::string>& arguments) {
  if (!desktop_feature_channel_ || arguments.empty()) {
    return;
  }
  flutter::EncodableList encoded_arguments;
  encoded_arguments.reserve(arguments.size());
  for (const std::string& argument : arguments) {
    encoded_arguments.emplace_back(argument);
  }
  desktop_feature_channel_->InvokeMethod(
      "openExternalArguments",
      std::make_unique<flutter::EncodableValue>(encoded_arguments));
}

void FlutterWindow::SendDesktopLyricsBounds() {
  if (!desktop_feature_channel_ || !desktop_lyrics_window_) {
    return;
  }
  RECT bounds;
  ::GetWindowRect(desktop_lyrics_window_, &bounds);
  const std::string encoded_bounds =
      "{\"x\":" + std::to_string(bounds.left) + ",\"y\":" +
      std::to_string(bounds.top) + ",\"width\":" +
      std::to_string(bounds.right - bounds.left) + ",\"height\":" +
      std::to_string(bounds.bottom - bounds.top) + "}";
  desktop_feature_channel_->InvokeMethod(
      "desktopLyricsBoundsChanged",
      std::make_unique<flutter::EncodableValue>(encoded_bounds));
}

void FlutterWindow::ApplyWindowControlsLight(bool light) {
  HWND window = GetHandle();
  BOOL dark_decorations = light ? TRUE : FALSE;
  ::DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &dark_decorations, sizeof(dark_decorations));

  COLORREF caption_color = light ? RGB(16, 20, 25) : RGB(246, 248, 251);
  COLORREF text_color = light ? RGB(255, 255, 255) : RGB(17, 17, 17);
  ::DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &caption_color,
                          sizeof(caption_color));
  ::DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &text_color,
                          sizeof(text_color));
}

void FlutterWindow::UpdateMediaSession(const flutter::EncodableMap& state) {
  namespace media = winrt::Windows::Media;
  namespace storage = winrt::Windows::Storage;
  namespace streams = winrt::Windows::Storage::Streams;

  const bool active = EncodableBool(state, "active");
  const bool playing = EncodableBool(state, "playing");
  UpdateTaskbarToolbar(active, playing);

  if (!active) {
    if (media_session_ && media_session_->controls) {
      media_session_->controls.PlaybackStatus(
          media::MediaPlaybackStatus::Closed);
      media_session_->controls.IsEnabled(false);
      auto updater = media_session_->controls.DisplayUpdater();
      updater.ClearAll();
      updater.Update();
    }
    return;
  }

  try {
    if (!media_session_) {
      try {
        winrt::init_apartment(winrt::apartment_type::single_threaded);
      } catch (const winrt::hresult_error& error) {
        if (error.code() != RPC_E_CHANGED_MODE) {
          throw;
        }
      }

      auto session = std::make_unique<WindowsMediaSessionState>();
      auto interop =
          winrt::get_activation_factory<media::SystemMediaTransportControls,
                                        ISystemMediaTransportControlsInterop>();
      winrt::check_hresult(interop->GetForWindow(
          GetHandle(), winrt::guid_of<media::SystemMediaTransportControls>(),
          winrt::put_abi(session->controls)));

      session->button_pressed_token =
          session->controls.ButtonPressed([this](
              media::SystemMediaTransportControls const&,
              media::SystemMediaTransportControlsButtonPressedEventArgs const&
                  args) {
            switch (args.Button()) {
              case media::SystemMediaTransportControlsButton::Play:
              case media::SystemMediaTransportControlsButton::Pause:
                SendDesktopCommand("play-pause");
                return;
              case media::SystemMediaTransportControlsButton::Previous:
                SendDesktopCommand("previous");
                return;
              case media::SystemMediaTransportControlsButton::Next:
                SendDesktopCommand("next");
                return;
              case media::SystemMediaTransportControlsButton::Stop:
                SendDesktopCommand("stop");
                return;
              default:
                return;
            }
          });

      session->playback_position_changed_token =
          session->controls.PlaybackPositionChangeRequested(
              [this](media::SystemMediaTransportControls const&,
                     media::PlaybackPositionChangeRequestedEventArgs const&
                         args) {
                const double seconds =
                    std::chrono::duration<double>(
                        args.RequestedPlaybackPosition())
                        .count();
                SendDesktopCommand("seek-to:" + std::to_string(seconds));
              });

      media_session_ = std::move(session);
    }

    auto controls = media_session_->controls;
    controls.IsEnabled(true);
    controls.IsPlayEnabled(true);
    controls.IsPauseEnabled(true);
    controls.IsStopEnabled(true);
    controls.IsPreviousEnabled(true);
    controls.IsNextEnabled(true);
    controls.PlaybackStatus(
        playing ? media::MediaPlaybackStatus::Playing
                : media::MediaPlaybackStatus::Paused);

    auto updater = controls.DisplayUpdater();
    updater.ClearAll();
    updater.Type(media::MediaPlaybackType::Music);
    auto music = updater.MusicProperties();
    music.Title(winrt::hstring(EncodableString(state, "title")));
    music.Artist(winrt::hstring(EncodableString(state, "artist")));
    music.AlbumTitle(winrt::hstring(EncodableString(state, "album")));

    const std::wstring artwork_path = EncodableString(state, "artworkPath");
    if (!artwork_path.empty()) {
      try {
        auto file = storage::StorageFile::GetFileFromPathAsync(
                        winrt::hstring(artwork_path))
                        .get();
        updater.Thumbnail(streams::RandomAccessStreamReference::CreateFromFile(
            file));
      } catch (const winrt::hresult_error&) {
      }
    }
    updater.Update();

    const double duration = EncodableDouble(state, "durationSeconds", 0);
    const double progress = EncodableDouble(state, "progressSeconds", 0);
    media::SystemMediaTransportControlsTimelineProperties timeline;
    timeline.StartTime(TimeSpanFromSeconds(0));
    timeline.MinSeekTime(TimeSpanFromSeconds(0));
    timeline.Position(TimeSpanFromSeconds(progress));
    timeline.MaxSeekTime(TimeSpanFromSeconds(duration));
    timeline.EndTime(TimeSpanFromSeconds(duration));
    controls.UpdateTimelineProperties(timeline);
  } catch (const winrt::hresult_error&) {
    media_session_.reset();
  }
}

void FlutterWindow::UpdateDesktopLyricsWindow(
    const flutter::EncodableMap& state) {
  if (!EncodableBool(state, "visible")) {
    HideDesktopLyricsWindow();
    return;
  }

  const std::wstring lyric_text = EncodableString(state, "lyricText");
  const std::wstring fallback_text = EncodableString(state, "fallbackText");
  desktop_lyrics_loading_ = EncodableBool(state, "loading");
  const std::wstring next_desktop_lyrics_text =
      desktop_lyrics_loading_
          ? L"..."
          : lyric_text.empty() ? fallback_text : lyric_text;
  if (desktop_lyrics_text_ != next_desktop_lyrics_text) {
    desktop_lyrics_text_started_at_ = ::GetTickCount64();
  }
  desktop_lyrics_text_ = next_desktop_lyrics_text;
  desktop_lyrics_title_ = EncodableString(state, "songTitle");
  desktop_lyrics_artist_ = EncodableString(state, "artist");
  desktop_lyrics_font_family_ = EncodableString(state, "fontFamily");
  if (desktop_lyrics_font_family_.empty() ||
      desktop_lyrics_font_family_ == L"system") {
    desktop_lyrics_font_family_ = L"Segoe UI";
  }
  desktop_lyrics_text_color_ =
      ColorFromHex(EncodableString(state, "textColor"), RGB(74, 168, 255));
  const std::wstring stroke_color = EncodableString(state, "strokeColor");
  desktop_lyrics_stroke_enabled_ = !stroke_color.empty();
  desktop_lyrics_stroke_color_ =
      desktop_lyrics_stroke_enabled_
          ? ColorFromHex(stroke_color, RGB(17, 17, 17))
          : RGB(0, 0, 0);
  desktop_lyrics_font_size_ = EncodableInt(state, "fontSize", 28);
  desktop_lyrics_opacity_ = EncodableInt(state, "opacity", 88);
  desktop_lyrics_locked_ = EncodableBool(state, "locked");
  desktop_lyrics_night_mode_ = EncodableBool(state, "nightMode");
  desktop_lyrics_playing_ = EncodableBool(state, "playing");
  wchar_t offset_buffer[32];
  const int offset_ms = EncodableInt(state, "offsetMs", 0);
  const double offset_seconds = std::round(offset_ms / 100.0) / 10.0;
  if (offset_seconds > 0) {
    swprintf_s(offset_buffer, L"+%.1fs", offset_seconds);
  } else if (offset_seconds < 0) {
    swprintf_s(offset_buffer, L"%.1fs", offset_seconds);
  } else {
    swprintf_s(offset_buffer, L"0s");
  }
  desktop_lyrics_offset_label_ = offset_buffer;
  desktop_lyrics_label_previous_ = EncodableString(state, "labelPrevious");
  desktop_lyrics_label_next_ = EncodableString(state, "labelNext");
  desktop_lyrics_label_play_pause_ = EncodableString(state, "labelPlayPause");
  desktop_lyrics_label_reset_offset_ =
      EncodableString(state, "labelResetOffset");
  desktop_lyrics_label_lock_ = EncodableString(state, "labelLock");
  desktop_lyrics_label_unlock_ = EncodableString(state, "labelUnlock");
  desktop_lyrics_label_settings_ = EncodableString(state, "labelSettings");
  desktop_lyrics_label_close_ = EncodableString(state, "labelClose");
  if (desktop_lyrics_label_previous_.empty()) {
    desktop_lyrics_label_previous_ = L"Previous";
  }
  if (desktop_lyrics_label_next_.empty()) {
    desktop_lyrics_label_next_ = L"Next";
  }
  if (desktop_lyrics_label_play_pause_.empty()) {
    desktop_lyrics_label_play_pause_ = L"Play/Pause";
  }
  if (desktop_lyrics_label_reset_offset_.empty()) {
    desktop_lyrics_label_reset_offset_ = L"Reset";
  }
  if (desktop_lyrics_label_lock_.empty()) {
    desktop_lyrics_label_lock_ = L"Lock";
  }
  if (desktop_lyrics_label_unlock_.empty()) {
    desktop_lyrics_label_unlock_ = L"Unlock";
  }
  if (desktop_lyrics_label_settings_.empty()) {
    desktop_lyrics_label_settings_ = L"Settings";
  }
  if (desktop_lyrics_label_close_.empty()) {
    desktop_lyrics_label_close_ = L"Close";
  }

  if (!desktop_lyrics_window_) {
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = FlutterWindow::DesktopLyricsWindowProc;
    window_class.hInstance = ::GetModuleHandleW(nullptr);
    window_class.lpszClassName = kDesktopLyricsWindowClass;
    window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
    ::RegisterClassW(&window_class);

    const RECT bounds =
        ResolveDesktopLyricsBounds(GetHandle(), EncodableString(state, "bounds"));
    desktop_lyrics_window_ = ::CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST,
        kDesktopLyricsWindowClass, L"Desktop Lyrics", WS_POPUP, bounds.left,
        bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top,
        nullptr, nullptr, ::GetModuleHandleW(nullptr), this);
    ::SetTimer(desktop_lyrics_window_, 1, 100, nullptr);
  }

  ::SetWindowPos(desktop_lyrics_window_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                     SWP_NOOWNERZORDER);
  ::SetTimer(desktop_lyrics_window_, 1,
             desktop_lyrics_scrolling_ ? 33 : 100, nullptr);
  if (!::IsWindowVisible(desktop_lyrics_window_)) {
    ::ShowWindow(desktop_lyrics_window_, SW_SHOWNOACTIVATE);
  }
  PaintDesktopLyricsWindow();
}

void FlutterWindow::HideDesktopLyricsWindow() {
  if (desktop_lyrics_window_) {
    desktop_lyrics_panel_visible_ = false;
    desktop_lyrics_tracking_mouse_leave_ = false;
    desktop_lyrics_hovered_button_command_.clear();
    desktop_lyrics_buttons_.clear();
    ::ShowWindow(desktop_lyrics_window_, SW_HIDE);
    ::KillTimer(desktop_lyrics_window_, 1);
  }
}

void FlutterWindow::DestroyDesktopLyricsWindow() {
  if (desktop_lyrics_window_) {
    ::KillTimer(desktop_lyrics_window_, 1);
    ::DestroyWindow(desktop_lyrics_window_);
    desktop_lyrics_window_ = nullptr;
  }
}

bool FlutterWindow::UpdateDesktopLyricsPanelVisibility(POINT point) {
  const bool next_panel_visible =
      desktop_lyrics_panel_visible_
          ? ::PtInRect(&desktop_lyrics_card_bounds_, point)
          : ::PtInRect(&desktop_lyrics_lyric_hit_bounds_, point);
  if (desktop_lyrics_panel_visible_ == next_panel_visible) {
    return false;
  }
  desktop_lyrics_panel_visible_ = next_panel_visible;
  if (!next_panel_visible) {
    desktop_lyrics_hovered_button_command_.clear();
    desktop_lyrics_buttons_.clear();
  }
  return true;
}

bool FlutterWindow::UpdateDesktopLyricsButtonHover(POINT point) {
  std::string next_command;
  if (desktop_lyrics_panel_visible_) {
    for (const DesktopLyricsButton& button : desktop_lyrics_buttons_) {
      if (!button.command.empty() && ::PtInRect(&button.bounds, point)) {
        next_command = button.command;
        break;
      }
    }
  }
  if (desktop_lyrics_hovered_button_command_ == next_command) {
    return false;
  }
  desktop_lyrics_hovered_button_command_ = next_command;
  return true;
}

void FlutterWindow::DismissNativeSplash() {
  if (!native_splash_visible_) {
    return;
  }
  native_splash_visible_ = false;
  if (flutter_controller_ && flutter_controller_->view()) {
    ::ShowWindow(flutter_controller_->view()->GetNativeWindow(), SW_SHOW);
    ::SetFocus(flutter_controller_->view()->GetNativeWindow());
  }
  ::InvalidateRect(GetHandle(), nullptr, TRUE);
}

void FlutterWindow::PaintNativeSplash() {
  PAINTSTRUCT paint;
  HDC hdc = ::BeginPaint(GetHandle(), &paint);
  RECT client_rect = GetClientArea();
  const bool dark = IsDarkModePreferred();

  HBRUSH background_brush =
      ::CreateSolidBrush(dark ? RGB(15, 19, 25) : RGB(247, 249, 252));
  ::FillRect(hdc, &client_rect, background_brush);
  ::DeleteObject(background_brush);

  const int center_x = (client_rect.right - client_rect.left) / 2;
  const int center_y = (client_rect.bottom - client_rect.top) / 2;
  RECT plate_rect{center_x - 66, center_y - 96, center_x + 66, center_y + 36};

  HBRUSH shadow_brush =
      ::CreateSolidBrush(dark ? RGB(5, 7, 10) : RGB(210, 230, 250));
  RECT shadow_rect = plate_rect;
  ::OffsetRect(&shadow_rect, 0, 12);
  ::FillRect(hdc, &shadow_rect, shadow_brush);
  ::DeleteObject(shadow_brush);

  HBRUSH plate_brush =
      ::CreateSolidBrush(dark ? RGB(24, 34, 48) : RGB(255, 255, 255));
  HPEN plate_pen =
      ::CreatePen(PS_SOLID, 1, dark ? RGB(38, 52, 70) : RGB(220, 232, 244));
  HGDIOBJ old_brush = ::SelectObject(hdc, plate_brush);
  HGDIOBJ old_pen = ::SelectObject(hdc, plate_pen);
  ::RoundRect(hdc, plate_rect.left, plate_rect.top, plate_rect.right,
              plate_rect.bottom, 32, 32);
  ::SelectObject(hdc, old_pen);
  ::SelectObject(hdc, old_brush);
  ::DeleteObject(plate_pen);
  ::DeleteObject(plate_brush);

  HICON icon = static_cast<HICON>(
      ::LoadImageW(::GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON),
                   IMAGE_ICON, 86, 86, LR_DEFAULTCOLOR));
  if (icon != nullptr) {
    ::DrawIconEx(hdc, center_x - 43, center_y - 73, icon, 86, 86, 0, nullptr,
                 DI_NORMAL);
    ::DestroyIcon(icon);
  }

  HFONT title_font = ::CreateFontW(
      22, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
  HGDIOBJ old_font = ::SelectObject(hdc, title_font);
  ::SetBkMode(hdc, TRANSPARENT);
  ::SetTextColor(hdc, dark ? RGB(244, 248, 255) : RGB(24, 32, 43));
  RECT title_rect{client_rect.left, center_y + 62, client_rect.right,
                  center_y + 96};
  ::DrawTextW(hdc, L"Simple Melody Player", -1, &title_rect,
              DT_CENTER | DT_SINGLELINE | DT_VCENTER);
  ::SelectObject(hdc, old_font);
  ::DeleteObject(title_font);

  ::EndPaint(GetHandle(), &paint);
}

void FlutterWindow::PaintDesktopLyricsWindow() {
  if (!desktop_lyrics_window_) {
    return;
  }
  RECT rect;
  ::GetClientRect(desktop_lyrics_window_, &rect);
  const int width = rect.right - rect.left;
  const int height = rect.bottom - rect.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  HDC screen_dc = ::GetDC(nullptr);
  HDC hdc = ::CreateCompatibleDC(screen_dc);
  BITMAPINFO bitmap_info = {};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP bitmap = ::CreateDIBSection(screen_dc, &bitmap_info, DIB_RGB_COLORS,
                                       &bits, nullptr, 0);
  HGDIOBJ old_bitmap = ::SelectObject(hdc, bitmap);

  void* text_mask_bits = nullptr;
  HDC text_mask_dc = ::CreateCompatibleDC(screen_dc);
  HBITMAP text_mask_bitmap = ::CreateDIBSection(
      screen_dc, &bitmap_info, DIB_RGB_COLORS, &text_mask_bits, nullptr, 0);
  HGDIOBJ old_text_mask_bitmap =
      ::SelectObject(text_mask_dc, text_mask_bitmap);
  HBRUSH text_mask_clear_brush = ::CreateSolidBrush(RGB(0, 0, 0));

  HBRUSH transparent_brush = ::CreateSolidBrush(RGB(0, 0, 0));
  ::FillRect(hdc, &rect, transparent_brush);
  ::DeleteObject(transparent_brush);

  const double layout_scale =
      std::min(width / 760.0, height / 148.0);
  auto scaled_metric = [layout_scale](int value) {
    return std::max(1, static_cast<int>(value * layout_scale + 0.5));
  };
  const BYTE card_background_alpha = static_cast<BYTE>(
      std::clamp(desktop_lyrics_opacity_, 0, 100) *
      (desktop_lyrics_night_mode_ ? 0.34 : 0.24) * 255 / 100);
  const BYTE card_border_alpha =
      static_cast<BYTE>((desktop_lyrics_night_mode_ ? 0.22 : 0.08) * 255);
  const BYTE button_background_alpha =
      static_cast<BYTE>((desktop_lyrics_night_mode_ ? 0.16 : 0.38) * 255);
  const BYTE button_hover_background_alpha =
      static_cast<BYTE>((desktop_lyrics_night_mode_ ? 0.72 : 0.96) * 255);

  auto* pixels = static_cast<unsigned char*>(bits);
  std::vector<bool> premultiplied_pixels(width * height, false);
  auto background_alpha = [&](const unsigned char* pixel) {
    if (pixel[0] == 0 && pixel[1] == 0 && pixel[2] == 0) {
      return static_cast<BYTE>(0);
    }
    const bool card_background =
        desktop_lyrics_night_mode_
            ? (pixel[0] == 18 && pixel[1] == 12 && pixel[2] == 8)
            : (pixel[0] == 255 && pixel[1] == 250 && pixel[2] == 245);
    const bool card_border =
        desktop_lyrics_night_mode_
            ? (pixel[0] == 255 && pixel[1] == 254 && pixel[2] == 253)
            : (pixel[0] == 42 && pixel[1] == 23 && pixel[2] == 15);
    const bool button_background =
        desktop_lyrics_night_mode_
            ? (pixel[0] == 16 && pixel[1] == 10 && pixel[2] == 6)
            : (pixel[0] == 255 && pixel[1] == 255 && pixel[2] == 255);
    const bool button_hover_background =
        desktop_lyrics_night_mode_
            ? (pixel[0] == 64 && pixel[1] == 52 && pixel[2] == 42)
            : (pixel[0] == 240 && pixel[1] == 230 && pixel[2] == 222);
    if (card_background) {
      return card_background_alpha;
    }
    if (card_border) {
      return card_border_alpha;
    }
    if (button_hover_background) {
      return button_hover_background_alpha;
    }
    if (button_background) {
      return button_background_alpha;
    }
    return static_cast<BYTE>(255);
  };
  auto premultiply_pixel = [&](int index) {
    if (premultiplied_pixels[index]) {
      return;
    }
    unsigned char* pixel = pixels + index * 4;
    const BYTE alpha = background_alpha(pixel);
    pixel[0] = static_cast<unsigned char>(pixel[0] * alpha / 255);
    pixel[1] = static_cast<unsigned char>(pixel[1] * alpha / 255);
    pixel[2] = static_cast<unsigned char>(pixel[2] * alpha / 255);
    pixel[3] = alpha;
    premultiplied_pixels[index] = true;
  };
  auto draw_alpha_text = [&](const std::wstring& text, RECT target,
                             UINT format) {
    RECT clip_bounds;
    ::GetClipBox(hdc, &clip_bounds);
    RECT mask_bounds;
    if (!::IntersectRect(&mask_bounds, &target, &clip_bounds)) {
      return;
    }

    ::FillRect(text_mask_dc, &mask_bounds, text_mask_clear_brush);
    const int saved_mask_dc = ::SaveDC(text_mask_dc);
    ::IntersectClipRect(text_mask_dc, clip_bounds.left, clip_bounds.top,
                        clip_bounds.right, clip_bounds.bottom);
    ::SelectObject(text_mask_dc, ::GetCurrentObject(hdc, OBJ_FONT));
    ::SetBkMode(text_mask_dc, TRANSPARENT);
    ::SetTextColor(text_mask_dc, RGB(255, 255, 255));
    RECT mask_target = target;
    ::DrawTextW(text_mask_dc, text.c_str(), -1, &mask_target, format);
    ::RestoreDC(text_mask_dc, saved_mask_dc);

    const COLORREF text_color = ::GetTextColor(hdc);
    const unsigned char source_blue = GetBValue(text_color);
    const unsigned char source_green = GetGValue(text_color);
    const unsigned char source_red = GetRValue(text_color);
    auto* mask_pixels = static_cast<unsigned char*>(text_mask_bits);
    for (int y = mask_bounds.top; y < mask_bounds.bottom; y += 1) {
      for (int x = mask_bounds.left; x < mask_bounds.right; x += 1) {
        const int index = y * width + x;
        const unsigned char coverage = mask_pixels[index * 4];
        if (coverage == 0) {
          continue;
        }
        premultiply_pixel(index);
        unsigned char* pixel = pixels + index * 4;
        const int inverse_coverage = 255 - coverage;
        pixel[0] = static_cast<unsigned char>(
            source_blue * coverage / 255 +
            pixel[0] * inverse_coverage / 255);
        pixel[1] = static_cast<unsigned char>(
            source_green * coverage / 255 +
            pixel[1] * inverse_coverage / 255);
        pixel[2] = static_cast<unsigned char>(
            source_red * coverage / 255 +
            pixel[2] * inverse_coverage / 255);
        pixel[3] = static_cast<unsigned char>(
            coverage + pixel[3] * inverse_coverage / 255);
      }
    }
  };

  RECT card = rect;
  ::InflateRect(&card, -scaled_metric(8), -scaled_metric(8));
  desktop_lyrics_card_bounds_ = card;
  desktop_lyrics_lyric_hit_bounds_ = {};
  desktop_lyrics_buttons_.clear();

  if (desktop_lyrics_panel_visible_) {
    HBRUSH card_brush = ::CreateSolidBrush(
        desktop_lyrics_night_mode_ ? RGB(8, 12, 18) : RGB(245, 250, 255));
    HPEN card_pen = ::CreatePen(
        PS_SOLID, 1,
        desktop_lyrics_night_mode_ ? RGB(253, 254, 255) : RGB(15, 23, 42));
    HGDIOBJ old_brush = ::SelectObject(hdc, card_brush);
    HGDIOBJ old_pen = ::SelectObject(hdc, card_pen);
    const int radius = scaled_metric(16);
    ::RoundRect(hdc, card.left, card.top, card.right, card.bottom, radius,
                radius);
    ::SelectObject(hdc, old_pen);
    ::SelectObject(hdc, old_brush);
    ::DeleteObject(card_pen);
    ::DeleteObject(card_brush);

    HFONT meta_font = ::CreateFontW(
        -scaled_metric(12), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        desktop_lyrics_font_family_.c_str());
    HFONT old_meta_font = static_cast<HFONT>(::SelectObject(hdc, meta_font));
    ::SetBkMode(hdc, TRANSPARENT);
    ::SetTextColor(hdc, desktop_lyrics_night_mode_ ? RGB(210, 218, 228)
                                                   : RGB(104, 113, 126));
    std::wstring meta_text = desktop_lyrics_title_;
    if (!desktop_lyrics_artist_.empty()) {
      meta_text += L"     ";
      meta_text += desktop_lyrics_artist_;
    }
    RECT meta_rect{card.left + scaled_metric(18), card.top + scaled_metric(10),
                   card.right - scaled_metric(18),
                   card.top + scaled_metric(28)};
    draw_alpha_text(meta_text, meta_rect,
                    DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    ::SelectObject(hdc, old_meta_font);
    ::DeleteObject(meta_font);

    std::vector<DesktopLyricsButton> specs = {
        {RECT{}, "previous", L"\xE100", true},
        {RECT{}, "play-pause", desktop_lyrics_playing_ ? L"\xE103" : L"\xE102",
         true},
        {RECT{}, "next", L"\xE101", true},
        {RECT{}, "", L"", false},
        {RECT{}, "offset:-100", L"-0.1s", false},
        {RECT{}, "offset:100", L"+0.1s", false},
        {RECT{}, "reset-offset", desktop_lyrics_offset_label_, false},
        {RECT{}, "", L"", false},
        {RECT{}, "toggle-lock",
         desktop_lyrics_locked_ ? L"\xE72E" : L"\xE785", true},
        {RECT{}, "open-settings", L"\xE713", true},
    };
    if (!desktop_lyrics_locked_) {
      specs.push_back({RECT{}, "disable", L"\xE711", true});
    }

    const int gap = scaled_metric(3);
    const int button_height = scaled_metric(26);
    std::vector<int> widths;
    widths.reserve(specs.size());
    int total_width = gap * (static_cast<int>(specs.size()) - 1);
    for (const DesktopLyricsButton& spec : specs) {
      int button_width = 26;
      if (spec.command == "offset:-100" ||
          spec.command == "offset:100") {
        button_width = scaled_metric(42);
      } else if (spec.command == "reset-offset") {
        button_width = scaled_metric(56);
      } else if (spec.command.empty()) {
        button_width = scaled_metric(9);
      } else {
        button_width = scaled_metric(button_width);
      }
      widths.push_back(button_width);
      total_width += button_width;
    }
    int x = card.left + ((card.right - card.left) - total_width) / 2;
    const int content_bottom = card.bottom - scaled_metric(1) -
                               scaled_metric(12);
    const int y = content_bottom - button_height -
                  (scaled_metric(30) - button_height) / 2;
    for (size_t index = 0; index < specs.size(); index += 1) {
      specs[index].bounds = RECT{x, y, x + widths[index], y + button_height};
      x += widths[index] + gap;
    }
    desktop_lyrics_buttons_ = specs;
  }

  const int font_height = -scaled_metric(desktop_lyrics_font_size_);
  HFONT lyrics_font = ::CreateFontW(
      font_height, 0, 0, 0, FW_EXTRABOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, desktop_lyrics_font_family_.c_str());
  HFONT old_font = static_cast<HFONT>(::SelectObject(hdc, lyrics_font));
  ::SetBkMode(hdc, TRANSPARENT);
  const int content_left = card.left + scaled_metric(1) + scaled_metric(18);
  const int content_right = card.right - scaled_metric(1) - scaled_metric(18);
  const int content_top = card.top + scaled_metric(1) + scaled_metric(10);
  const int content_bottom = card.bottom - scaled_metric(1) -
                             scaled_metric(12);
  const int meta_height = scaled_metric(16);
  const int toolbar_height = scaled_metric(30);
  const int row_gap = scaled_metric(6);
  const int lyric_top = content_top + meta_height + row_gap;
  const int toolbar_top = content_bottom - toolbar_height;
  RECT text_rect{content_left, lyric_top, content_right,
                 toolbar_top - row_gap};
  SIZE lyric_size = {};
  ::GetTextExtentPoint32W(
      hdc, desktop_lyrics_text_.c_str(),
      static_cast<int>(desktop_lyrics_text_.length()), &lyric_size);
  const int text_width = text_rect.right - text_rect.left;
  const int text_height = text_rect.bottom - text_rect.top;
  const int lyric_hit_height = std::min(
      text_height,
      std::max(1, static_cast<int>(desktop_lyrics_font_size_ * layout_scale *
                                       1.24 +
                                   0.5)));
  const int lyric_hit_top =
      text_rect.top + (text_height - lyric_hit_height) / 2;
  int lyric_hit_width = text_width;
  if (lyric_size.cx <= text_width) {
    const int span_padding = std::max(
        1, static_cast<int>(desktop_lyrics_font_size_ * layout_scale * 0.28 +
                            0.5));
    lyric_hit_width =
        std::min(text_width, static_cast<int>(lyric_size.cx) + span_padding);
  }
  const int lyric_hit_left =
      text_rect.left + (text_width - lyric_hit_width) / 2;
  desktop_lyrics_lyric_hit_bounds_ =
      RECT{lyric_hit_left, lyric_hit_top, lyric_hit_left + lyric_hit_width,
           lyric_hit_top + lyric_hit_height};
  auto draw_lyrics = [&](RECT target, UINT format) {
    if (desktop_lyrics_stroke_enabled_) {
      ::SetTextColor(hdc, desktop_lyrics_stroke_color_);
      for (int dx = -1; dx <= 1; dx += 1) {
        for (int dy = -1; dy <= 1; dy += 1) {
          if (dx == 0 && dy == 0) {
            continue;
          }
          RECT stroke_rect = target;
          ::OffsetRect(&stroke_rect, dx, dy);
          draw_alpha_text(desktop_lyrics_text_, stroke_rect, format);
        }
      }
    }
    ::SetTextColor(hdc, desktop_lyrics_text_color_);
    draw_alpha_text(desktop_lyrics_text_, target, format);
  };
  const bool lyrics_scrolling = lyric_size.cx > text_width;
  if (desktop_lyrics_scrolling_ != lyrics_scrolling) {
    desktop_lyrics_scrolling_ = lyrics_scrolling;
    ::SetTimer(desktop_lyrics_window_, 1, lyrics_scrolling ? 33 : 100,
               nullptr);
  }
  if (lyrics_scrolling) {
    const int distance = lyric_size.cx - text_width;
    const int duration_ms =
        std::min(12000, std::max(5000, ((distance / scaled_metric(28)) + 4) *
                                       1000));
    const ULONGLONG elapsed =
        ::GetTickCount64() - desktop_lyrics_text_started_at_;
    const int cycle_ms = duration_ms * 2;
    const int phase = static_cast<int>(elapsed % cycle_ms);
    const double raw_progress =
        phase <= duration_ms
            ? static_cast<double>(phase) / duration_ms
            : 1.0 - static_cast<double>(phase - duration_ms) / duration_ms;
    const double eased_progress =
        raw_progress * raw_progress * (3.0 - 2.0 * raw_progress);
    const int saved_dc = ::SaveDC(hdc);
    ::IntersectClipRect(hdc, text_rect.left, text_rect.top, text_rect.right,
                        text_rect.bottom);
    RECT scrolling_rect = text_rect;
    scrolling_rect.left -= static_cast<int>(distance * eased_progress);
    scrolling_rect.right = scrolling_rect.left + lyric_size.cx;
    draw_lyrics(scrolling_rect,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOCLIP);
    ::RestoreDC(hdc, saved_dc);
  } else {
    draw_lyrics(text_rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE |
                               DT_END_ELLIPSIS);
  }

  if (desktop_lyrics_panel_visible_ && !desktop_lyrics_buttons_.empty()) {
    HFONT button_font = ::CreateFontW(
        -scaled_metric(11), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    HFONT icon_font = ::CreateFontW(
        -scaled_metric(16), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        L"Segoe MDL2 Assets");
    HFONT old_button_font =
        static_cast<HFONT>(::SelectObject(hdc, button_font));
    ::SetBkMode(hdc, TRANSPARENT);
    ::SetTextColor(hdc, desktop_lyrics_night_mode_ ? RGB(244, 248, 255)
                                                   : RGB(42, 48, 58));
    HBRUSH button_brush = ::CreateSolidBrush(
        desktop_lyrics_night_mode_ ? RGB(6, 10, 16) : RGB(255, 255, 255));
    HBRUSH button_hover_brush = ::CreateSolidBrush(
        desktop_lyrics_night_mode_ ? RGB(42, 52, 64) : RGB(222, 230, 240));
    for (const DesktopLyricsButton& button : desktop_lyrics_buttons_) {
      if (button.command.empty()) {
        continue;
      }
      const bool hovered =
          button.command == desktop_lyrics_hovered_button_command_;
      ::FillRect(hdc, &button.bounds,
                 hovered ? button_hover_brush : button_brush);
      ::SelectObject(hdc, button.icon ? icon_font : button_font);
      RECT label_rect = button.bounds;
      draw_alpha_text(button.label, label_rect,
                      DT_CENTER | DT_VCENTER | DT_SINGLELINE |
                          DT_END_ELLIPSIS);
    }
    ::DeleteObject(button_hover_brush);
    ::DeleteObject(button_brush);
    ::SelectObject(hdc, old_button_font);
    ::DeleteObject(icon_font);
    ::DeleteObject(button_font);
  }

  ::SelectObject(hdc, old_font);
  ::DeleteObject(lyrics_font);

  for (int index = 0; index < width * height; index += 1) {
    if (premultiplied_pixels[index]) {
      continue;
    }
    premultiply_pixel(index);
  }

  RECT window_rect;
  ::GetWindowRect(desktop_lyrics_window_, &window_rect);
  POINT destination{window_rect.left, window_rect.top};
  SIZE size{width, height};
  POINT source{0, 0};
  BLENDFUNCTION blend = {};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;
  ::UpdateLayeredWindow(desktop_lyrics_window_, screen_dc, &destination, &size,
                        hdc, &source, 0, &blend, ULW_ALPHA);

  ::SelectObject(hdc, old_bitmap);
  ::DeleteObject(text_mask_clear_brush);
  ::SelectObject(text_mask_dc, old_text_mask_bitmap);
  ::DeleteObject(text_mask_bitmap);
  ::DeleteDC(text_mask_dc);
  ::DeleteObject(bitmap);
  ::DeleteDC(hdc);
  ::ReleaseDC(nullptr, screen_dc);
}

LRESULT CALLBACK FlutterWindow::DesktopLyricsWindowProc(HWND hwnd, UINT message,
                                                        WPARAM wparam,
                                                        LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto* create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    ::SetWindowLongPtrW(
        hwnd, GWLP_USERDATA,
        reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
  }
  auto* window = reinterpret_cast<FlutterWindow*>(
      ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (!window) {
    return ::DefWindowProcW(hwnd, message, wparam, lparam);
  }

  switch (message) {
    case WM_ERASEBKGND:
      return 1;
    case WM_MOUSEMOVE:
      {
        POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        const bool panel_changed =
            window->UpdateDesktopLyricsPanelVisibility(point);
        const bool hover_changed = window->UpdateDesktopLyricsButtonHover(point);
        if (panel_changed || hover_changed) {
          window->PaintDesktopLyricsWindow();
        }
        ::SetCursor(::LoadCursor(
            nullptr, window->desktop_lyrics_hovered_button_command_.empty()
                         ? IDC_ARROW
                         : IDC_HAND));
      }
      if (!window->desktop_lyrics_tracking_mouse_leave_) {
        TRACKMOUSEEVENT track_mouse_event = {};
        track_mouse_event.cbSize = sizeof(TRACKMOUSEEVENT);
        track_mouse_event.dwFlags = TME_LEAVE;
        track_mouse_event.hwndTrack = hwnd;
        if (::TrackMouseEvent(&track_mouse_event)) {
          window->desktop_lyrics_tracking_mouse_leave_ = true;
        }
      }
      return 0;
    case WM_MOUSELEAVE:
      if (window->desktop_lyrics_panel_visible_) {
        window->desktop_lyrics_panel_visible_ = false;
        window->desktop_lyrics_hovered_button_command_.clear();
        window->desktop_lyrics_buttons_.clear();
        window->PaintDesktopLyricsWindow();
      }
      window->desktop_lyrics_tracking_mouse_leave_ = false;
      return 0;
    case WM_LBUTTONDOWN:
      {
        const POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        for (const DesktopLyricsButton& button :
             window->desktop_lyrics_buttons_) {
          if (button.command.empty()) {
            continue;
          }
          if (::PtInRect(&button.bounds, point)) {
            window->SendDesktopCommand(button.command);
            return 0;
          }
        }
        if (!window->desktop_lyrics_locked_) {
          ::ReleaseCapture();
          ::SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
        }
      }
      return 0;
    case WM_EXITSIZEMOVE:
    case WM_MOVE:
      window->SendDesktopLyricsBounds();
      return 0;
    case WM_TIMER:
      {
        bool repaint = window->desktop_lyrics_scrolling_;
        POINT cursor_position;
        RECT window_rect;
        if (::GetCursorPos(&cursor_position) &&
            ::GetWindowRect(hwnd, &window_rect) &&
            ::PtInRect(&window_rect, cursor_position)) {
          ::ScreenToClient(hwnd, &cursor_position);
          repaint |=
              window->UpdateDesktopLyricsPanelVisibility(cursor_position);
        } else if (window->desktop_lyrics_panel_visible_) {
          window->desktop_lyrics_panel_visible_ = false;
          window->desktop_lyrics_tracking_mouse_leave_ = false;
          window->desktop_lyrics_hovered_button_command_.clear();
          window->desktop_lyrics_buttons_.clear();
          repaint = true;
        }
        if (repaint) {
          window->PaintDesktopLyricsWindow();
        }
      }
      return 0;
    case WM_PAINT:
      {
        PAINTSTRUCT paint;
        ::BeginPaint(hwnd, &paint);
        ::EndPaint(hwnd, &paint);
        window->PaintDesktopLyricsWindow();
      }
      return 0;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

void FlutterWindow::OnDestroy() {
  DestroyDesktopLyricsWindow();
  if (taskbar_previous_icon_ != nullptr) {
    ::DestroyIcon(taskbar_previous_icon_);
    taskbar_previous_icon_ = nullptr;
  }
  if (taskbar_play_icon_ != nullptr) {
    ::DestroyIcon(taskbar_play_icon_);
    taskbar_play_icon_ = nullptr;
  }
  if (taskbar_pause_icon_ != nullptr) {
    ::DestroyIcon(taskbar_pause_icon_);
    taskbar_pause_icon_ = nullptr;
  }
  if (taskbar_next_icon_ != nullptr) {
    ::DestroyIcon(taskbar_next_icon_);
    taskbar_next_icon_ = nullptr;
  }
  taskbar_list_.Reset();
  if (media_session_ && media_session_->controls) {
    media_session_->controls.ButtonPressed(
        media_session_->button_pressed_token);
    media_session_->controls.PlaybackPositionChangeRequested(
        media_session_->playback_position_changed_token);
    media_session_->controls.PlaybackStatus(
        winrt::Windows::Media::MediaPlaybackStatus::Closed);
    media_session_->controls.IsEnabled(false);
    media_session_.reset();
  }
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
  if (native_splash_visible_) {
    switch (message) {
      case WM_ERASEBKGND:
        return 1;
      case WM_PAINT:
        PaintNativeSplash();
        return 0;
    }
  }

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
    case WM_COMMAND:
      if (HIWORD(wparam) == THBN_CLICKED) {
        switch (LOWORD(wparam)) {
          case kTaskbarButtonPrevious:
            SendDesktopCommand("previous");
            return 0;
          case kTaskbarButtonPlayPause:
            SendDesktopCommand("play-pause");
            return 0;
          case kTaskbarButtonNext:
            SendDesktopCommand("next");
            return 0;
        }
      }
      break;
    case WM_COPYDATA: {
      const auto* copy_data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
      if (copy_data->dwData != kOpenExternalArgumentsCopyDataType) {
        break;
      }
      const auto* command_line =
          reinterpret_cast<const wchar_t*>(copy_data->lpData);
      int argument_count = 0;
      wchar_t** arguments = ::CommandLineToArgvW(command_line, &argument_count);
      if (arguments == nullptr) {
        return 0;
      }
      std::vector<std::string> external_arguments;
      external_arguments.reserve(argument_count);
      for (int index = 1; index < argument_count; index += 1) {
        external_arguments.push_back(Utf8FromUtf16(arguments[index]));
      }
      ::LocalFree(arguments);
      SendOpenExternalArguments(external_arguments);
      if (::IsIconic(hwnd)) {
        ::ShowWindow(hwnd, SW_RESTORE);
      }
      ::SetForegroundWindow(hwnd);
      return 0;
    }
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

  if (taskbar_button_created_message_ != 0 &&
      message == taskbar_button_created_message_) {
    taskbar_buttons_added_ = false;
    taskbar_list_.Reset();
    UpdateTaskbarToolbar(taskbar_media_active_, taskbar_media_playing_);
    return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
