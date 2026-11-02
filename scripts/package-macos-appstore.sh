#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
project_dir="$PWD"
flutter_sdk="${FLUTTER_ROOT:-$HOME/Documents/flutter}"
version="$(sed -n 's/^version: *\([^ ]*\).*/\1/p' pubspec.yaml)"
build_name="${version%%+*}"
build_number="${version#*+}"
[[ "$version" == *+* ]] || { echo 'pubspec.yaml 必须包含版本号和构建号，例如 4.0.2+1'; exit 1; }
archive="$project_dir/build/macos/archive/Simple Melody Player-$build_name-build-$build_number.xcarchive"
export_dir="$project_dir/build/macos/appstore-$build_name-build-$build_number"
[[ ! -e "$archive" && ! -e "$export_dir" ]] || { echo '该版本的归档或安装包已存在；请先更新 pubspec.yaml 中的构建号。'; exit 1; }

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/smplayer-package.XXXXXXXX")"
cleanup() {
  for file in Flutter-Generated.xcconfig flutter_export_environment.sh flutter_native_integration.env FlutterInputs.xcfilelist; do
    path="$project_dir/macos/Flutter/ephemeral/$file"
    if [[ -f "$path" ]]; then
      /usr/bin/sed -i '' "s|$temp_dir/flutter|$flutter_sdk|g" "$path"
    fi
  done
}
trap cleanup EXIT

echo "正在准备 $version 的依赖和构建工具..."
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
"$flutter_sdk/bin/flutter" pub get --enforce-lockfile

# Some Xcode lipo versions reject multiple arguments to -verify_arch.
framework="$flutter_sdk/bin/cache/artifacts/engine/darwin-x64-release/FlutterMacOS.framework/Versions/A/FlutterMacOS"
if [[ -f "$framework" ]] && /usr/bin/lipo "$framework" -verify_arch arm64 && /usr/bin/lipo "$framework" -verify_arch x86_64 && ! /usr/bin/lipo "$framework" -verify_arch arm64 x86_64 2>/dev/null; then
  echo '当前 lipo 需要逐个验证架构，使用临时 Flutter SDK 副本。'
  cp -cR "$flutter_sdk" "$temp_dir/flutter"
  /usr/bin/python3 - "$temp_dir/flutter/packages/flutter_tools/lib/src/build_system/targets/darwin.dart" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
old = """    final ProcessResult verifyResult = await environment.processManager.run(<String>[
      'lipo',
      frameworkBinaryPath,
      '-verify_arch',
      ...archList,
    ]);

    if (verifyResult.exitCode != 0) {
      throw Exception(
        'Binary $frameworkBinaryPath does not contain architectures \"$archs\".\\n'
        '\\n'
        'lipo -info:\\n'
        '$lipoInfo',
      );
    }
"""
new = """    for (final arch in archList) {
      final result = await environment.processManager.run(<String>[
        'lipo', frameworkBinaryPath, '-verify_arch', arch,
      ]);
      if (result.exitCode != 0) {
        throw Exception('Binary $frameworkBinaryPath does not contain architecture \"$arch\".\\n$lipoInfo');
      }
    }
"""
if text.count(old) != 1:
    raise SystemExit('Flutter 架构校验代码发生变化，请检查后再打包。')
path.write_text(text.replace(old, new))
PY
  mv "$temp_dir/flutter/bin/cache/flutter_tools.snapshot" "$temp_dir/flutter/bin/cache/flutter_tools.original.snapshot"
  build_flutter="$temp_dir/flutter/bin/flutter"
else
  build_flutter="$flutter_sdk/bin/flutter"
fi

"$build_flutter" build macos --release --no-pub
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$archive" \
  -derivedDataPath "$project_dir/build/macos/store-$build_name-build-$build_number" archive

cat > "$temp_dir/ExportOptions.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>destination</key><string>export</string>
<key>manageAppVersionAndBuildNumber</key><false/>
<key>method</key><string>app-store-connect</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>7LB7J48HY7</string>
<key>uploadSymbols</key><true/>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export_dir" \
  -exportOptionsPlist "$temp_dir/ExportOptions.plist" -allowProvisioningUpdates

app="$archive/Products/Applications/Simple Melody Player.app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$build_name" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")" == "$build_number" ]]
for arch in arm64 x86_64; do /usr/bin/lipo "$app/Contents/MacOS/Simple Melody Player" -verify_arch "$arch"; done
pkgutil --check-signature "$export_dir/Simple Melody Player.pkg"
echo "打包完成：$export_dir/Simple Melody Player.pkg"
echo '安装包未上传；请在 App Store Connect 中上传并检查处理结果。'
