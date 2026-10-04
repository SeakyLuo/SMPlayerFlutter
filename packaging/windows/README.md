# Windows Store package

In Codex, run the **打包 Windows 商店** action. From a Windows terminal:

```cmd
.codex\environments\package-windows.cmd
```

Requires Flutter on PATH, Visual Studio C++ desktop build tools and the Windows
10/11 SDK. The entry point prepares the Windows build environment, restores the
locked Dart dependencies, builds Release, includes the native DLLs and Visual C++
runtime, then runs MakeAppx with manifest validation enabled.

Output: `build/store/SMPlayer-<version>-x64.msix`. Version comes from the first
three components of `pubspec.yaml`; the Store revision is always `0`.
The manifest preserves the original Store identity, publisher and `App` ID.
The package does not contain your database, playback queue or other personal data.

The package is **unsigned**, intended for submission to the existing Store app.
This command does not install certificates, install the app or submit it.
Local installation needs signing; validate the old-to-new upgrade and data
preservation in a separate Windows account/device before public release. Also
confirm that its version exceeds the latest package in Partner Center.

Only x64 is packaged. The manifest retains the old Windows 10 build 17763 minimum;
compatibility with that OS version still needs device validation.

The Windows audio plugin is pinned to upstream commit
`46c084850e25cd8b629fcf5054c01496ddd5e9ab` (1.0.10), providing architecture-specific
x64/ARM64 audio libraries. It is not yet a pub.dev release. GitHub access is
required on a fresh build machine. This dependency update alone does not produce
or validate an ARM64 application package.
ARM64 library archives require a recent 7-Zip (`7z` or `7za` on PATH); the CMake
bundled with Visual Studio 2019 cannot decode their ARM64 compression filter.

For packaging an already-built Release without rebuilding (not the release action):

```cmd
.codex\environments\package-windows.cmd -SkipBuild
```

Independent staging directories are kept under `build/store` for inspection.
The three manifest icons were copied from the original UWP scale-100 assets.
