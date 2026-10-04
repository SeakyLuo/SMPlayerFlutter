#ifndef RUNNER_DESKTOP_LYRICS_GLASS_H_
#define RUNNER_DESKTOP_LYRICS_GLASS_H_

#include <windows.h>

HWND CreateDesktopLyricsGlassWindow();

bool ApplyDesktopLyricsGlassMaterial(HWND window, bool dark);

void ShowDesktopLyricsGlassWindow(HWND window,
                                  HWND foreground_window,
                                  const RECT& foreground_client_bounds);

void HideDesktopLyricsGlassWindow(HWND window);

#endif  // RUNNER_DESKTOP_LYRICS_GLASS_H_
