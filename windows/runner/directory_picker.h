#ifndef RUNNER_DIRECTORY_PICKER_H_
#define RUNNER_DIRECTORY_PICKER_H_

#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <windows.h>
#include <memory>

constexpr UINT kDirectoryPickerCompleted = WM_APP + 120;

void PickDirectory(
    HWND owner, const flutter::EncodableMap& arguments,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
void CompleteDirectoryPicker(LPARAM payload);

#endif  // RUNNER_DIRECTORY_PICKER_H_
