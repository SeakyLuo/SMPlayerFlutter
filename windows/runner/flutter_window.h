#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <shobjidl.h>
#include <string>
#include <vector>
#include <wrl/client.h>

#include "win32_window.h"

struct DesktopLyricsButton {
  RECT bounds;
  std::string command;
  std::wstring label;
  bool icon;
};

struct WindowsMediaSessionState;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RegisterDesktopFeatureChannel();
  void RegisterGlobalMediaHotkeys();
  void UnregisterGlobalMediaHotkeys();
  void SendDesktopCommand(const std::string& command);
  void SendOpenExternalArguments(const std::vector<std::string>& arguments);
  void SendDesktopLyricsBounds();
  void ApplyWindowControlsLight(bool light);
  void UpdateMediaSession(const flutter::EncodableMap& state);
  void EnsureTaskbarToolbar();
  void UpdateTaskbarToolbar(bool active, bool playing);
  void UpdateDesktopLyricsWindow(const flutter::EncodableMap& state);
  void HideDesktopLyricsWindow();
  void DestroyDesktopLyricsWindow();
  void PaintDesktopLyricsWindow();
  bool UpdateDesktopLyricsPanelVisibility(POINT point);
  void DismissNativeSplash();
  void PaintNativeSplash();
  static LRESULT CALLBACK DesktopLyricsWindowProc(HWND hwnd, UINT message,
                                                  WPARAM wparam,
                                                  LPARAM lparam);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_feature_channel_;
  std::unique_ptr<WindowsMediaSessionState> media_session_;
  Microsoft::WRL::ComPtr<ITaskbarList3> taskbar_list_;
  UINT taskbar_button_created_message_ = 0;
  bool taskbar_buttons_added_ = false;
  bool taskbar_media_active_ = false;
  bool taskbar_media_playing_ = false;
  HICON taskbar_previous_icon_ = nullptr;
  HICON taskbar_play_icon_ = nullptr;
  HICON taskbar_pause_icon_ = nullptr;
  HICON taskbar_next_icon_ = nullptr;
  bool native_splash_visible_ = false;
  HWND hot_key_window_ = nullptr;
  HWND desktop_lyrics_window_ = nullptr;
  std::wstring desktop_lyrics_text_;
  ULONGLONG desktop_lyrics_text_started_at_ = 0;
  std::wstring desktop_lyrics_title_;
  std::wstring desktop_lyrics_artist_;
  std::wstring desktop_lyrics_font_family_ = L"Segoe UI";
  COLORREF desktop_lyrics_text_color_ = RGB(74, 168, 255);
  COLORREF desktop_lyrics_stroke_color_ = RGB(17, 17, 17);
  int desktop_lyrics_font_size_ = 28;
  int desktop_lyrics_opacity_ = 88;
  bool desktop_lyrics_locked_ = false;
  bool desktop_lyrics_loading_ = false;
  bool desktop_lyrics_night_mode_ = true;
  bool desktop_lyrics_playing_ = false;
  bool desktop_lyrics_panel_visible_ = false;
  bool desktop_lyrics_tracking_mouse_leave_ = false;
  bool desktop_lyrics_stroke_enabled_ = false;
  std::wstring desktop_lyrics_label_previous_ = L"Previous";
  std::wstring desktop_lyrics_label_next_ = L"Next";
  std::wstring desktop_lyrics_label_play_pause_ = L"Play/Pause";
  std::wstring desktop_lyrics_offset_label_ = L"0.0s";
  std::wstring desktop_lyrics_label_reset_offset_ = L"Reset";
  std::wstring desktop_lyrics_label_lock_ = L"Lock";
  std::wstring desktop_lyrics_label_unlock_ = L"Unlock";
  std::wstring desktop_lyrics_label_settings_ = L"Settings";
  std::wstring desktop_lyrics_label_close_ = L"Close";
  RECT desktop_lyrics_card_bounds_ = {};
  RECT desktop_lyrics_lyric_hit_bounds_ = {};
  std::vector<DesktopLyricsButton> desktop_lyrics_buttons_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
