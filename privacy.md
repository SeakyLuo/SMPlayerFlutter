# 简音播放器 · 隐私政策

Simple Melody Player · macOS  
生效日期 / Effective date: 2026-10-25  
开发者 / Developer: SeakyLuo

## 隐私政策

本政策说明 SeakyLuo（下称“我们”）开发的简音播放器 macOS 版如何处理信息。简音播放器用于播放和管理本地音乐，无需注册应用账号。我们不在应用中投放广告，也不使用广告标识符或跨应用跟踪技术。

### 1. 本地音乐与应用数据

当你选择文件或音乐目录后，应用会读取音频文件、文件路径、歌曲名称、歌手、专辑、封面、歌词及其他音频标签，用于建立音乐库、播放、搜索、显示歌词和编辑歌曲信息。音乐库索引、播放列表、收藏、播放记录、搜索记录、播放进度、设置、封面缓存及文件访问授权记录保存在你的 Mac 上。

应用不会为了云端备份或广告分析而上传完整音乐库或音频文件。你主动使用导出、备份、标签编辑或歌词保存功能时，应用会按操作内容创建或修改相应的本地文件。你自行分享的导出文件可能包含音乐库信息和文件路径。

### 2. 联网歌词与外部搜索

使用联网歌词功能时，应用会向 QQ 音乐的服务接口发送歌曲名称、歌手或相关搜索词，并使用匹配结果中的歌曲标识请求歌词。请求服务能够接收到网络连接所需的 IP 地址和请求信息；这些接口请求不会主动附带你的完整音乐库或音频文件。

**“自动添加歌词”默认开启**，导入或更新音乐库时可能触发联网歌词查询。你可在设置中关闭自动添加歌词；关闭后，手动联网搜索仍会在你主动使用时发送相应查询。

选择在浏览器中搜索歌词时，应用会打开包含歌曲名称、歌手和“歌词”等关键词的 Bing 搜索页面。搜索提供商和浏览器依照其自身的隐私政策处理该次访问。

### 3. 语音助手

语音助手仅在你主动打开并授予麦克风及语音识别权限后使用语音输入。应用使用 macOS 提供的语音识别服务将语音转换为文字，并在应用中解析播放、暂停、音量和搜索等指令。识别过程可能由设备本地或 Apple 的服务器完成，取决于系统、语言及服务能力；不能保证所有识别均离线进行。

应用不主动保存原始录音或建立语音历史库。识别文字用于当前助手会话和执行指令；指令触发的音乐搜索等操作可能产生通常的本地历史记录。如果使用语音合成播报，待播报文字由系统语音合成服务处理。你可以关闭助手，并在 macOS 系统设置的隐私与安全性中撤销权限；这不会影响普通音乐播放。

Apple 对语音数据的处理请参阅 [Siri、听写与隐私说明](https://www.apple.com/legal/privacy/data/en/ask-siri-dictation/)。

### 4. 错误诊断

当前 macOS 版本集成了 Microsoft App Center 错误报告。应用发生受捕获的错误或未处理异常时，会自动尝试向该服务发送诊断报告，用于定位故障和改善稳定性。

报告包括随机生成并保存在本机的安装标识、会话标识、错误标识、发生时间、启动时间、进程信息、应用版本、系统版本、语言、时区以及异常类型、错误消息和堆栈。服务提供商还可接收网络连接所需的 IP 地址。错误消息和堆栈可能包含相关文件路径、歌曲信息或其他运行上下文；当前实现没有对这些文本进行全面脱敏。诊断报告不会主动附加音频文件或完整音乐库。

当前版本**没有独立的错误报告开关**。因此本应用不能被视为完全离线、完全不传输信息的应用。诊断处理也受 [Microsoft 隐私声明](https://www.microsoft.com/en-us/privacy/privacystatement)及适用的服务条款约束。

### 5. 可选的本地 AI 工具接口

“AI Agent”接口默认关闭。你启用后，应用会在本机回环地址上提供接口，供同一台 Mac 上的程序读取播放状态、歌曲元数据、设置及音乐库数据库路径，并按接口能力控制播放或修改歌曲信息。该接口不监听局域网或公网地址，但同机其他程序可能访问它；请仅在信任相关工具时启用。

启用这个接口本身不会让播放器自动连接某个云端大模型。如果你让第三方 AI 工具读取音乐库或调用接口，第三方工具是否向外部服务器传输所读信息，取决于该工具的配置和隐私政策。你可在设置中关闭接口以停止后续接口访问；已被其他工具保存的数据不会随之自动删除。

### 6. 反馈与第三方服务

你通过电子邮件或 GitHub 提交反馈时，我们会收到你主动提供的内容和用于回复的联系信息。GitHub 公开 Issue 的内容可能被其他人看到，请勿上传密码、完整音乐库或不希望公开的个人信息。为处理请求，我们可能保留相关通信记录。

我们不会出售你的个人信息，也不会将音乐库数据用于广告画像。应用涉及的外部接收方主要是上述歌词服务、Apple 系统语音服务、Microsoft 诊断或搜索服务，以及你主动使用的反馈或第三方工具服务。第三方可能在你所在国家或地区以外处理数据，其处理地点、保留期限和权利渠道依照相应政策及适用要求执行。

本政策页面和项目仓库如托管于 GitHub，访问页面时 GitHub 会按 [GitHub 隐私声明](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)处理网站访问数据。本文档本身不嵌入广告或第三方分析脚本。

### 7. 保存期限、删除与选择

- **本地数据：**应用数据保留至你通过应用提供的相应操作删除，或自行移除应用数据。仅卸载应用不一定删除设置、缓存、数据库或已导出的文件。需要完整清除时，请先备份所需内容并联系我们获取操作帮助；删除应用数据不等于删除你原来的音乐文件，反之亦然。
- **联网功能：**你可关闭自动添加歌词、不使用手动联网搜索、关闭本地 AI 接口，或撤销语音权限。撤销权限和停用功能只影响后续处理，不会自动撤回已发送给第三方的信息。
- **诊断和反馈：**已接收的报告和通信仅为故障分析、支持处理及必要的安全或法律义务保留；相关第三方服务的保存及删除还受其规则和服务配置约束。本政策不承诺未经核实的统一保存天数。如需查询或删除与自己有关的信息，请通过下方邮箱联系我们。我们会核实请求并在适用法律规定的期限内处理，说明可执行的删除及依法需保留的情况。

在适用法律赋予相关权利的范围内，你也可以联系开发者请求访问、更正、删除、限制处理或获取可携带的数据副本，并撤回基于同意作出的授权。大部分音乐库数据仅存于你的设备，我们无法远程读取、导出或替你删除这些本地数据。

### 8. 安全与未成年人

应用使用 macOS 沙盒和系统文件授权限制文件访问，联网歌词与诊断接口使用 HTTPS。没有任何存储或传输方式能够保证绝对安全。应用不专门面向儿童，不要求提供年龄或儿童个人信息；如监护人认为儿童已向我们提供个人信息，可联系开发者处理。

### 9. 政策变更与联系方式

应用功能或信息处理方式变化时，我们会更新本政策和生效日期。涉及重要隐私变化时，我们会通过适当方式告知，并在需要时取得授权。

开发者：SeakyLuo  
隐私问题、访问或删除请求：[luokiss9@qq.com](mailto:luokiss9@qq.com)  
项目与支持：[github.com/SeakyLuo/SMPlayerFlutter](https://github.com/SeakyLuo/SMPlayerFlutter)

---

## Privacy Policy

This policy describes how the macOS version of Simple Melody Player, developed by SeakyLuo (“we”), handles information. The app plays and manages local music and does not require an app account. It contains no advertising and does not use advertising identifiers or cross-app tracking technologies.

### 1. Local music and app data

After you select files or music folders, the app reads audio files, file paths, titles, artists, albums, artwork, lyrics and other audio tags to build your library, play music, search, display lyrics and edit song information. Library indexes, playlists, favorites, playback and search history, playback position, preferences, artwork caches and file-access authorizations are stored on your Mac.

The app does not upload your complete library or audio files for cloud backup or advertising analytics. Export, backup, tag-editing and lyric-saving actions create or modify local files as requested. Exported files that you choose to share may contain library information and file paths.

### 2. Online lyrics and external searches

Online lyric features send song titles, artists or related search terms to QQ Music service endpoints and use a matching song identifier to request lyrics. The provider can receive your IP address and request information needed for the connection. These requests do not intentionally include your complete library or audio files.

**Automatically adding lyrics is enabled by default** and may initiate requests when importing or updating a library. You can disable this setting. Manual online searches still send the relevant query when you choose to use them.

Searching for lyrics in a browser opens Bing with the song title, artist and a lyric-related keyword. The search provider and browser process that visit under their own policies.

### 3. Voice assistant

The assistant uses voice input when you open it and grant microphone and speech-recognition permissions. macOS speech services convert speech to text, which the app interprets as playback, volume, search or other supported commands. Recognition may occur on-device or on Apple servers depending on the system, language and service capabilities; it is not guaranteed to be fully offline.

The app does not intentionally save raw recordings or maintain a voice-history database. Recognized text is used for the current assistant session and command execution. Actions such as music searches may create ordinary local history records. Spoken responses are processed by the system text-to-speech service. You can close the assistant or revoke permissions in macOS Privacy & Security settings without affecting ordinary music playback.

For Apple's handling of speech data, see [Siri, Dictation & Privacy](https://www.apple.com/legal/privacy/data/en/ask-siri-dictation/).

### 4. Error diagnostics

The current macOS version integrates Microsoft App Center error reporting. When a captured error or unhandled exception occurs, the app automatically attempts to send a diagnostic report to help investigate faults and improve reliability.

Reports include a randomly generated, locally persisted installation identifier, session and error identifiers, event and launch timestamps, process information, app and operating-system versions, language, time zone, exception type, error message and stack trace. The provider can also receive the IP address used for the connection. Error messages and traces may include relevant file paths, song information or other runtime context; the current implementation does not comprehensively redact these texts. Reports do not intentionally attach audio files or the complete library.

The current version **does not provide a separate error-reporting switch**. It must therefore not be understood as entirely offline or as transmitting no information. Diagnostic processing is also subject to the [Microsoft Privacy Statement](https://www.microsoft.com/en-us/privacy/privacystatement) and applicable service terms.

### 5. Optional local AI tool interface

The AI Agent interface is off by default. When enabled, it exposes a loopback interface for programs on the same Mac to read playback state, song metadata, settings and the library database path, and to control playback or modify song information through supported operations. It does not listen on LAN or public addresses, but other local programs may be able to access it. Enable it only for tools you trust.

Enabling this interface does not itself connect the player to a cloud language model. Whether a third-party AI tool sends information it reads to external servers depends on that tool's configuration and privacy policy. Disabling the interface stops subsequent interface access; it does not delete copies already retained by other tools.

### 6. Feedback and third-party services

When you send feedback by email or GitHub, we receive the content you provide and contact information needed to respond. Public GitHub issues may be visible to others; do not include passwords, complete libraries or information you do not want to make public. We may retain correspondence needed to handle your request.

We do not sell personal information or use library data for advertising profiles. External recipients principally comprise the lyric provider, Apple's system speech services, Microsoft's diagnostic or search services, and feedback or third-party tool services you choose to use. Providers may process data outside your country or region. Their processing locations, retention and rights channels are governed by their policies and applicable requirements.

If this policy or the project is hosted on GitHub, GitHub processes website visits under its [Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). This document itself embeds no advertising or third-party analytics scripts.

### 7. Retention, deletion and choices

- **Local data:** App data remains until removed through relevant app operations or deleted by you. Uninstalling alone may leave settings, caches, databases or exported files. Contact us for help with a complete cleanup after backing up anything you wish to keep. Deleting app data and deleting your original music files are separate actions.
- **Connected features:** You can disable automatic lyrics, avoid manual online searches, disable the local AI interface or revoke speech permissions. These choices affect future processing and do not automatically withdraw information already sent to providers.
- **Diagnostics and feedback:** Received reports and correspondence are retained for fault investigation, support and necessary security or legal obligations. Provider retention and deletion are also subject to their rules and service configuration. We do not promise an unverified uniform retention period. Contact the email below to inquire about or request deletion of information relating to you. We will verify and handle requests within applicable legal deadlines and explain available deletion actions or legally required retention.

Where applicable law provides these rights, you may also request access, correction, deletion, restriction of processing or a portable copy, and withdraw consent-based authorizations. Most library data exists only on your device; we cannot remotely read, export or delete that local data for you.

### 8. Security and children

The app uses macOS sandboxing and system file permissions to restrict file access, and HTTPS for online lyric and diagnostic requests. No storage or transmission method guarantees absolute security. The app is not specifically directed at children and does not request age or children's personal information. A parent or guardian who believes a child has provided personal information to us can contact us for assistance.

### 9. Changes and contact

We will update this policy and its effective date when features or information practices change. Material privacy changes will be communicated appropriately, with authorization obtained where required.

Developer: SeakyLuo  
Privacy questions, access or deletion requests: [luokiss9@qq.com](mailto:luokiss9@qq.com)  
Project and support: [github.com/SeakyLuo/SMPlayerFlutter](https://github.com/SeakyLuo/SMPlayerFlutter)
