#include "flutter_window.h"

#include <dwmapi.h>
#include <optional>
#include <propkey.h>
#include <propvarutil.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <algorithm>
#include <cwchar>
#include <string>
#include <variant>
#include <vector>
#include <windows.h>
#include <windowsx.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

constexpr int kHotKeyPlayPause = 5001;
constexpr int kHotKeyPrevious = 5002;
constexpr int kHotKeyNext = 5003;
constexpr int kHotKeyStop = 5004;
constexpr wchar_t kWindowsAppUserModelId[] = L"com.seaky.simplemelodyplayer";
constexpr ULONG_PTR kOpenExternalArgumentsCopyDataType = 0x534D504F;
constexpr wchar_t kDesktopLyricsWindowClass[] = L"SMPlayerDesktopLyricsWindow";

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

std::wstring EncodableString(const flutter::EncodableMap& map, const char* key) {
  const auto iterator = map.find(flutter::EncodableValue(key));
  if (iterator == map.end()) {
    return std::wstring();
  }
  const auto* value = std::get_if<std::string>(&iterator->second);
  return value == nullptr ? std::wstring() : Utf16FromUtf8(*value);
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

void FlutterWindow::UpdateDesktopLyricsWindow(
    const flutter::EncodableMap& state) {
  if (!EncodableBool(state, "visible")) {
    HideDesktopLyricsWindow();
    return;
  }

  const std::wstring lyric_text = EncodableString(state, "lyricText");
  const std::wstring fallback_text = EncodableString(state, "fallbackText");
  desktop_lyrics_loading_ = EncodableBool(state, "loading");
  desktop_lyrics_text_ =
      desktop_lyrics_loading_
          ? L"..."
          : lyric_text.empty() ? fallback_text : lyric_text;
  desktop_lyrics_next_text_ = EncodableString(state, "nextLyricText");
  desktop_lyrics_title_ = EncodableString(state, "songTitle");
  desktop_lyrics_artist_ = EncodableString(state, "artist");
  desktop_lyrics_font_family_ = EncodableString(state, "fontFamily");
  if (desktop_lyrics_font_family_.empty() ||
      desktop_lyrics_font_family_ == L"system") {
    desktop_lyrics_font_family_ = L"Segoe UI";
  }
  desktop_lyrics_text_color_ =
      ColorFromHex(EncodableString(state, "textColor"), RGB(74, 168, 255));
  desktop_lyrics_stroke_color_ =
      ColorFromHex(EncodableString(state, "strokeColor"), RGB(17, 17, 17));
  desktop_lyrics_font_size_ = EncodableInt(state, "fontSize", 28);
  desktop_lyrics_opacity_ = EncodableInt(state, "opacity", 88);
  desktop_lyrics_locked_ = EncodableBool(state, "locked");
  desktop_lyrics_night_mode_ = EncodableBool(state, "nightMode");
  desktop_lyrics_playing_ = EncodableBool(state, "playing");
  wchar_t offset_buffer[32];
  swprintf_s(offset_buffer, L"%+.1fs",
             EncodableInt(state, "offsetMs", 0) / 1000.0);
  desktop_lyrics_offset_label_ = offset_buffer;
  desktop_lyrics_label_previous_ = EncodableString(state, "labelPrevious");
  desktop_lyrics_label_next_ = EncodableString(state, "labelNext");
  desktop_lyrics_label_play_pause_ = EncodableString(state, "labelPlayPause");
  desktop_lyrics_label_play_ = EncodableString(state, "labelPlay");
  desktop_lyrics_label_pause_ = EncodableString(state, "labelPause");
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
  if (desktop_lyrics_label_play_.empty()) {
    desktop_lyrics_label_play_ = L"Play";
  }
  if (desktop_lyrics_label_pause_.empty()) {
    desktop_lyrics_label_pause_ = L"Pause";
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
    ::SetLayeredWindowAttributes(desktop_lyrics_window_, RGB(0, 0, 0), 0,
                                 LWA_COLORKEY);
  }

  LONG_PTR style = ::GetWindowLongPtrW(desktop_lyrics_window_, GWL_EXSTYLE);
  if (desktop_lyrics_locked_) {
    style |= WS_EX_TRANSPARENT;
  } else {
    style &= ~WS_EX_TRANSPARENT;
  }
  ::SetWindowLongPtrW(desktop_lyrics_window_, GWL_EXSTYLE, style);
  ::SetWindowPos(desktop_lyrics_window_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  ::ShowWindow(desktop_lyrics_window_, SW_SHOWNOACTIVATE);
  ::InvalidateRect(desktop_lyrics_window_, nullptr, TRUE);
}

void FlutterWindow::HideDesktopLyricsWindow() {
  if (desktop_lyrics_window_) {
    ::ShowWindow(desktop_lyrics_window_, SW_HIDE);
  }
}

void FlutterWindow::DestroyDesktopLyricsWindow() {
  if (desktop_lyrics_window_) {
    ::DestroyWindow(desktop_lyrics_window_);
    desktop_lyrics_window_ = nullptr;
  }
}

void FlutterWindow::PaintDesktopLyricsWindow() {
  PAINTSTRUCT paint;
  HDC hdc = ::BeginPaint(desktop_lyrics_window_, &paint);
  RECT rect;
  ::GetClientRect(desktop_lyrics_window_, &rect);
  HBRUSH transparent_brush = ::CreateSolidBrush(RGB(0, 0, 0));
  ::FillRect(hdc, &rect, transparent_brush);
  ::DeleteObject(transparent_brush);

  RECT card = rect;
  ::InflateRect(&card, -10, -10);
  HBRUSH card_brush = ::CreateSolidBrush(
      desktop_lyrics_night_mode_ ? RGB(16, 24, 32) : RGB(245, 248, 252));
  ::FillRect(hdc, &card, card_brush);
  ::DeleteObject(card_brush);
  desktop_lyrics_buttons_.clear();

  if (!desktop_lyrics_locked_) {
    const std::vector<DesktopLyricsButton> buttons = {
        {RECT{card.left + 10, card.top + 8, card.left + 48, card.top + 34},
         "previous", L"<<"},
        {RECT{card.left + 52, card.top + 8, card.left + 112, card.top + 34},
         "play-pause", desktop_lyrics_label_play_pause_},
        {RECT{card.left + 116, card.top + 8, card.left + 154, card.top + 34},
         "next", L">>"},
        {RECT{card.left + 166, card.top + 8, card.left + 214, card.top + 34},
         "offset:-100", L"-0.1"},
        {RECT{card.left + 218, card.top + 8, card.left + 266, card.top + 34},
         "offset:100", L"+0.1"},
        {RECT{card.left + 270, card.top + 8, card.left + 326, card.top + 34},
         "reset-offset", desktop_lyrics_offset_label_},
        {RECT{card.right - 238, card.top + 8, card.right - 184, card.top + 34},
         "toggle-lock", desktop_lyrics_locked_ ? desktop_lyrics_label_unlock_
                                                : desktop_lyrics_label_lock_},
        {RECT{card.right - 180, card.top + 8, card.right - 102, card.top + 34},
         "open-settings", desktop_lyrics_label_settings_},
        {RECT{card.right - 98, card.top + 8, card.right - 40, card.top + 34},
         "disable", desktop_lyrics_label_close_},
    };
    desktop_lyrics_buttons_ = buttons;
    HFONT button_font = ::CreateFontW(
        -MulDiv(12, 96, 72), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    HFONT old_button_font = static_cast<HFONT>(::SelectObject(hdc, button_font));
    ::SetBkMode(hdc, TRANSPARENT);
    ::SetTextColor(hdc, desktop_lyrics_night_mode_ ? RGB(225, 235, 245)
                                                   : RGB(32, 42, 54));
    HBRUSH button_brush = ::CreateSolidBrush(
        desktop_lyrics_night_mode_ ? RGB(42, 52, 64) : RGB(222, 230, 240));
    for (const DesktopLyricsButton& button : desktop_lyrics_buttons_) {
      ::FillRect(hdc, &button.bounds, button_brush);
      RECT label_rect = button.bounds;
      ::DrawTextW(hdc, button.label.c_str(), -1, &label_rect,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    }
    ::DeleteObject(button_brush);
    ::SelectObject(hdc, old_button_font);
    ::DeleteObject(button_font);
  }

  const int font_height = -MulDiv(desktop_lyrics_font_size_, 96, 72);
  HFONT lyrics_font = ::CreateFontW(
      font_height, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE, desktop_lyrics_font_family_.c_str());
  HFONT old_font = static_cast<HFONT>(::SelectObject(hdc, lyrics_font));
  ::SetBkMode(hdc, TRANSPARENT);
  ::SetTextColor(hdc, desktop_lyrics_text_color_);
  RECT text_rect = card;
  text_rect.left += 18;
  text_rect.right -= 18;
  text_rect.top += desktop_lyrics_locked_ ? 26 : 42;
  text_rect.bottom -= desktop_lyrics_next_text_.empty() ? 16 : 42;
  ::DrawTextW(hdc, desktop_lyrics_text_.c_str(), -1, &text_rect,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

  if (!desktop_lyrics_next_text_.empty()) {
    HFONT next_font = ::CreateFontW(
        -MulDiv(std::max(13, desktop_lyrics_font_size_ - 8), 96, 72), 0, 0, 0,
        FW_SEMIBOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
        CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        desktop_lyrics_font_family_.c_str());
    ::SelectObject(hdc, next_font);
    ::SetTextColor(hdc, RGB(170, 190, 210));
    RECT next_rect = card;
    next_rect.left += 18;
    next_rect.right -= 18;
    next_rect.top = card.bottom - 38;
    next_rect.bottom = card.bottom - 10;
    ::DrawTextW(hdc, desktop_lyrics_next_text_.c_str(), -1, &next_rect,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    ::SelectObject(hdc, lyrics_font);
    ::DeleteObject(next_font);
  }

  ::SelectObject(hdc, old_font);
  ::DeleteObject(lyrics_font);
  ::EndPaint(desktop_lyrics_window_, &paint);
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
    case WM_LBUTTONDOWN:
      if (!window->desktop_lyrics_locked_) {
        const POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        for (const DesktopLyricsButton& button :
             window->desktop_lyrics_buttons_) {
          if (::PtInRect(&button.bounds, point)) {
            window->SendDesktopCommand(button.command);
            return 0;
          }
        }
        ::ReleaseCapture();
        ::SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
      }
      return 0;
    case WM_EXITSIZEMOVE:
    case WM_MOVE:
      window->SendDesktopLyricsBounds();
      return 0;
    case WM_PAINT:
      window->PaintDesktopLyricsWindow();
      return 0;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

void FlutterWindow::OnDestroy() {
  DestroyDesktopLyricsWindow();
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

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
