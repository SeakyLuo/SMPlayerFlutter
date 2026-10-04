if(NOT CONFIG STREQUAL "Debug")
  return()
endif()
execute_process(
  COMMAND "$ENV{SystemRoot}/System32/WindowsPowerShell/v1.0/powershell.exe"
    -NoProfile -NonInteractive -ExecutionPolicy Bypass
    -File "${PROJECT_ROOT}/scripts/register-windows-development.ps1"
    -ExecutableDirectory "${APP_DIRECTORY}"
  RESULT_VARIABLE registration_result
)
if(NOT registration_result EQUAL 0)
  message(FATAL_ERROR "Windows development identity registration failed (${registration_result}).")
endif()
