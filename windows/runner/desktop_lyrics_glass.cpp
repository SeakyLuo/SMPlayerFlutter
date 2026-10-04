#include "desktop_lyrics_glass.h"

#include <dwmapi.h>

namespace {

constexpr wchar_t kDesktopLyricsGlassWindowClass[] =
    L"SMPlayerDesktopLyricsGlassWindow";
constexpr DWORD kDwmSystemBackdropType = 38;
constexpr DWORD kDwmWindowCornerPreference = 33;
constexpr DWORD kDwmUseImmersiveDarkMode = 20;
constexpr int kDwmBackdropTransientWindow = 3;
constexpr int kDwmCornerRound = 2;

enum class AccentState {
  disabled = 0,
  blurBehind = 3,
};

struct AccentPolicy {
  AccentState state;
  DWORD flags;
  DWORD gradient_color;
  DWORD animation_id;
};

enum class WindowCompositionAttribute {
  accentPolicy = 19,
};

struct WindowCompositionAttributeData {
  WindowCompositionAttribute attribute;
  PVOID data;
  SIZE_T size;
};

using SetWindowCompositionAttribute = BOOL(WINAPI*)(
    HWND window,
    WindowCompositionAttributeData* data);

LRESULT CALLBACK DesktopLyricsGlassWindowProc(HWND window,
                                              UINT message,
                                              WPARAM wparam,
                                              LPARAM lparam) {
  switch (message) {
    case WM_NCHITTEST:
      return HTTRANSPARENT;
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT:
      {
        PAINTSTRUCT paint;
        // DWM owns the glass background; an opaque GDI fill hides the desktop.
        ::BeginPaint(window, &paint);
        ::EndPaint(window, &paint);
      }
      return 0;
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

bool ApplyCompositionBlur(HWND window) {
  const HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  const auto set_window_composition_attribute =
      reinterpret_cast<SetWindowCompositionAttribute>(
          ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (!set_window_composition_attribute) {
    return false;
  }

  AccentPolicy policy = {};
  // Explicit neutral tint avoids inheriting the system accent color.
  policy.state = AccentState::blurBehind;
  policy.flags = 2;
  policy.gradient_color = 0;
  WindowCompositionAttributeData data = {};
  data.attribute = WindowCompositionAttribute::accentPolicy;
  data.data = &policy;
  data.size = sizeof(policy);
  return set_window_composition_attribute(window, &data) == TRUE;
}

}  // namespace

HWND CreateDesktopLyricsGlassWindow() {
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = DesktopLyricsGlassWindowProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kDesktopLyricsGlassWindowClass;
  window_class.hbrBackground = nullptr;
  ::RegisterClassW(&window_class);

  return ::CreateWindowExW(
      WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_TRANSPARENT,
      kDesktopLyricsGlassWindowClass, L"", WS_POPUP, 0, 0, 1, 1, nullptr,
      nullptr, ::GetModuleHandleW(nullptr), nullptr);
}

bool ApplyDesktopLyricsGlassMaterial(HWND window, bool dark) {
  BOOL dark_mode = dark ? TRUE : FALSE;
  ::DwmSetWindowAttribute(
      window, static_cast<DWMWINDOWATTRIBUTE>(kDwmUseImmersiveDarkMode),
      &dark_mode, sizeof(dark_mode));
  const int corner_preference = kDwmCornerRound;
  ::DwmSetWindowAttribute(
      window, static_cast<DWMWINDOWATTRIBUTE>(kDwmWindowCornerPreference),
      &corner_preference, sizeof(corner_preference));
  MARGINS margins{-1, -1, -1, -1};
  ::DwmExtendFrameIntoClientArea(window, &margins);

  const int no_backdrop = 1;
  ::DwmSetWindowAttribute(
      window, static_cast<DWMWINDOWATTRIBUTE>(kDwmSystemBackdropType),
      &no_backdrop, sizeof(no_backdrop));
  if (ApplyCompositionBlur(window)) {
    return true;
  }

  const int backdrop_type = kDwmBackdropTransientWindow;
  if (SUCCEEDED(::DwmSetWindowAttribute(
          window, static_cast<DWMWINDOWATTRIBUTE>(kDwmSystemBackdropType),
          &backdrop_type, sizeof(backdrop_type)))) {
    return true;
  }
  return false;
}

void ShowDesktopLyricsGlassWindow(HWND window,
                                  HWND foreground_window,
                                  const RECT& foreground_client_bounds) {
  POINT corners[2] = {
      {foreground_client_bounds.left, foreground_client_bounds.top},
      {foreground_client_bounds.right, foreground_client_bounds.bottom},
  };
  ::MapWindowPoints(foreground_window, nullptr, corners, 2);
  const int width = corners[1].x - corners[0].x;
  const int height = corners[1].y - corners[0].y;
  ::SetWindowRgn(window, ::CreateRoundRectRgn(0, 0, width + 1, height + 1,
                                              16, 16),
                 FALSE);
  ::SetWindowPos(window, foreground_window, corners[0].x, corners[0].y,
                 width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
  ::RedrawWindow(window, nullptr, nullptr,
                 RDW_ERASE | RDW_INVALIDATE | RDW_UPDATENOW);
  ::SetWindowPos(foreground_window, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                     SWP_NOOWNERZORDER);
}

void HideDesktopLyricsGlassWindow(HWND window) {
  ::ShowWindow(window, SW_HIDE);
}
