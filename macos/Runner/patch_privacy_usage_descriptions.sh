#!/bin/sh
set -e

MICROPHONE_USAGE="Simple Melody Player uses the microphone for voice assistant commands."
SPEECH_USAGE="Simple Melody Player uses speech recognition to run voice assistant commands."
APP_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
PATCHED_BUNDLES="${TARGET_TEMP_DIR}/privacy_patched_bundles.txt"

: > "$PATCHED_BUNDLES"

patch_plist() {
  plist="$1"
  /usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription $MICROPHONE_USAGE" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string $MICROPHONE_USAGE" "$plist"
  /usr/libexec/PlistBuddy -c "Set :NSSpeechRecognitionUsageDescription $SPEECH_USAGE" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string $SPEECH_USAGE" "$plist"

  bundle="$plist"
  while [ "$bundle" != "/" ] &&
    [ -n "$bundle" ] &&
    [ "${bundle##*.}" != "framework" ] &&
    [ "${bundle##*.}" != "bundle" ] &&
    [ "${bundle##*.}" != "app" ]; do
    bundle="${bundle%/*}"
  done

  case "$bundle" in
    *.framework | *.bundle) printf '%s\n' "$bundle" >> "$PATCHED_BUNDLES" ;;
  esac
}

patch_strings() {
  strings="$1"
  /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$strings" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string $MICROPHONE_USAGE" "$strings"
  /usr/libexec/PlistBuddy -c "Print :NSSpeechRecognitionUsageDescription" "$strings" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :NSSpeechRecognitionUsageDescription string $SPEECH_USAGE" "$strings"
}

scan_root() {
  root="$1"
  [ -d "$root" ] || return 0
  find "$root" \( \
    -name Info.plist -path "*.framework/*" -o \
    -name Info.plist -path "*.bundle/*" -o \
    -name Info.plist -path "*.app/*" \
    \) -print
}

{
  scan_root "$TARGET_BUILD_DIR"
  scan_root "$APP_DIR"
} | sort -u | while IFS= read -r plist; do
  patch_plist "$plist"
done

{
  find "$TARGET_BUILD_DIR" -name InfoPlist.strings -path "*.lproj/*" -print 2>/dev/null
  find "$APP_DIR" -name InfoPlist.strings -path "*.lproj/*" -print 2>/dev/null
} | sort -u | while IFS= read -r strings; do
  patch_strings "$strings"
done

if [ -d "$APP_DIR" ]; then
  touch "$APP_DIR"
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]; then
  SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  [ -n "$SIGN_IDENTITY" ] || SIGN_IDENTITY="-"
  sort -u "$PATCHED_BUNDLES" | while IFS= read -r bundle; do
    [ -d "$bundle" ] || continue
    codesign --force --sign "$SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements,flags,runtime "$bundle"
  done
  if [ -d "$APP_DIR" ]; then
    codesign --force --sign "$SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements,flags,runtime "$APP_DIR"
  fi
fi
