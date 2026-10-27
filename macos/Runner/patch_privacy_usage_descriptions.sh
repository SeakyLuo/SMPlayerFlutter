#!/bin/sh
set -e

MICROPHONE_USAGE="Simple Melody Player uses the microphone for voice assistant commands."
SPEECH_USAGE="Simple Melody Player uses speech recognition to run voice assistant commands."
APP_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

patch_plist() {
  plist="$1"
  /usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription $MICROPHONE_USAGE" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string $MICROPHONE_USAGE" "$plist"
  /usr/libexec/PlistBuddy -c "Set :NSSpeechRecognitionUsageDescription $SPEECH_USAGE" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string $SPEECH_USAGE" "$plist"

}

patch_strings() {
  strings="$1"
  /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$strings" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string $MICROPHONE_USAGE" "$strings"
  /usr/libexec/PlistBuddy -c "Print :NSSpeechRecognitionUsageDescription" "$strings" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string $SPEECH_USAGE" "$strings"
}

patch_plist "$APP_DIR/Contents/Info.plist"

find "$APP_DIR/Contents/Resources" -maxdepth 2 -name InfoPlist.strings -path "*.lproj/*" -print |
  while IFS= read -r strings; do
    patch_strings "$strings"
  done
