#include "flutter_window.h"

#include <commctrl.h>

void FlutterWindow::UpdateDesktopLyricsTooltips() {
  if (!desktop_lyrics_panel_visible_) {
    if (desktop_lyrics_tooltips_active_) {
      ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_ACTIVATE, FALSE, 0);
      desktop_lyrics_tooltips_active_ = false;
    }
    return;
  }

  if (!desktop_lyrics_tooltip_window_) {
    INITCOMMONCONTROLSEX controls = {sizeof(controls), ICC_WIN95_CLASSES};
    ::InitCommonControlsEx(&controls);
    desktop_lyrics_tooltip_window_ = ::CreateWindowExW(
        WS_EX_TOPMOST | WS_EX_NOACTIVATE, TOOLTIPS_CLASSW, nullptr,
        WS_POPUP | TTS_ALWAYSTIP | TTS_NOPREFIX, CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT, desktop_lyrics_window_, nullptr,
        ::GetModuleHandleW(nullptr), nullptr);
    if (!desktop_lyrics_tooltip_window_) {
      return;
    }
    ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_SETMAXTIPWIDTH, 0, 360);
  }

  const std::map<std::string, std::wstring> labels = {
      {"previous", desktop_lyrics_label_previous_},
      {"play-pause", desktop_lyrics_label_play_pause_},
      {"next", desktop_lyrics_label_next_},
      {"offset:-100", desktop_lyrics_label_delay_},
      {"offset:100", desktop_lyrics_label_advance_},
      {"reset-offset", desktop_lyrics_label_reset_offset_},
      {"toggle-lock", desktop_lyrics_locked_ ? desktop_lyrics_label_unlock_
                                            : desktop_lyrics_label_lock_},
      {"open-settings", desktop_lyrics_label_settings_},
      {"disable", desktop_lyrics_label_close_},
  };
  std::map<UINT_PTR, DesktopLyricsTooltip> next_tools;
  for (size_t index = 0; index < desktop_lyrics_buttons_.size(); ++index) {
    const auto& button = desktop_lyrics_buttons_[index];
    if (!button.command.empty()) {
      next_tools.emplace(index + 1, DesktopLyricsTooltip{
                                       button.bounds, labels.at(button.command)});
    }
  }

  for (auto it = desktop_lyrics_tooltips_.begin();
       it != desktop_lyrics_tooltips_.end();) {
    if (next_tools.count(it->first) == 0) {
      TOOLINFOW info = {};
      info.cbSize = sizeof(info);
      info.hwnd = desktop_lyrics_window_;
      info.uId = it->first;
      ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_DELTOOLW, 0,
                     reinterpret_cast<LPARAM>(&info));
      it = desktop_lyrics_tooltips_.erase(it);
    } else {
      ++it;
    }
  }
  for (const auto& [id, tool] : next_tools) {
    const auto found = desktop_lyrics_tooltips_.find(id);
    const bool added = found == desktop_lyrics_tooltips_.end();
    if (!added && ::EqualRect(&found->second.bounds, &tool.bounds) &&
        found->second.text == tool.text) {
      continue;
    }
    auto& stored = desktop_lyrics_tooltips_[id];
    stored = tool;
    TOOLINFOW info = {};
    info.cbSize = sizeof(info);
    info.hwnd = desktop_lyrics_window_;
    info.uId = id;
    info.uFlags = TTF_SUBCLASS;
    info.rect = stored.bounds;
    info.lpszText = stored.text.data();
    if (added) {
      ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_ADDTOOLW, 0,
                     reinterpret_cast<LPARAM>(&info));
    } else {
      ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_UPDATETIPTEXTW, 0,
                     reinterpret_cast<LPARAM>(&info));
      ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_NEWTOOLRECTW, 0,
                     reinterpret_cast<LPARAM>(&info));
    }
  }
  if (!desktop_lyrics_tooltips_active_) {
    ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_ACTIVATE, TRUE, 0);
    desktop_lyrics_tooltips_active_ = true;
  }
}

void FlutterWindow::DismissDesktopLyricsTooltip() {
  if (desktop_lyrics_tooltip_window_) {
    ::SendMessageW(desktop_lyrics_tooltip_window_, TTM_POP, 0, 0);
  }
}

void FlutterWindow::DestroyDesktopLyricsTooltips() {
  if (desktop_lyrics_tooltip_window_) {
    ::DestroyWindow(desktop_lyrics_tooltip_window_);
    desktop_lyrics_tooltip_window_ = nullptr;
  }
  desktop_lyrics_tooltips_.clear();
  desktop_lyrics_tooltips_active_ = false;
}
