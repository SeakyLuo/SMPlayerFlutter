cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "application_data_path.cpp"
  "desktop_lyrics_glass.cpp"
  "desktop_lyrics_tooltips.cpp"
  "directory_picker.cpp"
  "windows_speech_recognition.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app flutter_wrapper_plugin)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "ole32.lib" "propsys.lib" "runtimeobject.lib" "shell32.lib" "comctl32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only Debug builds acquire the sparse development identity. Store builds use
# packaging/windows/AppxManifest.xml and retain their existing package identity.
target_sources(${BINARY_NAME} PRIVATE
  "$<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/development.exe.manifest>"
)
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND "${CMAKE_COMMAND}"
    "-DCONFIG=$<CONFIG>"
    "-DAPP_DIRECTORY=$<TARGET_FILE_DIR:${BINARY_NAME}>"
    "-DPROJECT_ROOT=${CMAKE_SOURCE_DIR}/.."
    -P "${CMAKE_CURRENT_SOURCE_DIR}/register_development_identity.cmake"
  VERBATIM
)
