# Project Notes

- Original UWP project for parity checks: `C:\Users\luoki\source\repos\SMPlayer\SMPlayer`
- Then migrated to Electron: `C:\Users\luoki\Desktop\Projects\Electron\SMPlayer`//Users/luohaitian/Desktop/Projects/SMPlayerElectron (You should mostly referred to this project and should follow its logic very strictly)
- Now want to migrate to Flutter for all platforms(Win/Mac/Android/Flutter)

本任务禁止自行推断业务逻辑和 UI。
Electron 是唯一标准。

执行顺序：
1. 先定位 Electron 对应源码、CSS、helper、调用点。
2. 列出 Electron 的真实 UI 规则和业务流程。
3. 再定位 Flutter 对应实现。
4. 逐项列出 Flutter 和 Electron 的差异。
5. 只改差异，不做额外重构。
6. 改完必须用截图/运行行为/测试证明。
7. 没有证据的地方必须标为“未确认”，不能说已对齐。

## Electron 对齐硬性规则

这个项目不是重新设计，也不是用 Flutter 习惯重写。迁移任务里 Electron 是唯一 truth source；除非用户明确要求改变行为，否则 Flutter 必须复制 Electron 的 UI、交互和业务逻辑。

### 禁止事项

- 禁止在没找到 Electron 原始依据时自行补业务逻辑。
- 禁止把“没找到”当成“不存在”；只能标为“未确认”。
- 禁止用 Flutter 当前实现、常识、控件默认行为或个人审美反推 Electron 行为。
- 禁止为了兼容不可能发生的输入做防御性编程、normalize 或空校验。
- 禁止改未确认项；未确认项必须先停下来说明缺什么证据。
- 禁止只看一个相似文件就声称全局对齐。
- 禁止只跑 analyze/test 就声称 UI 像素级对齐。
- 禁止在前端主动显示 ID、调试信息、开发信息。

### 开始实现前必须完成覆盖性审计

任何“对齐原版 / 一模一样 / parity / 迁移”的任务，先审计，后实现。审计必须覆盖：

1. Electron 对应源码：组件、CSS、helper、hook/service、状态来源。
2. Electron 调用点：用 `rg` 查所有相关入口和复用位置，不只看第一个命中的文件。
3. Electron 运行效果：涉及 UI 时必须在相同主题、窗口尺寸、数据状态下截图或实际操作验证。
4. Flutter 对应源码：组件、样式、状态、service/repository、调用点。
5. Flutter 调用点：用 `rg` 查所有相关入口和复用位置。
6. 差异清单：逐项列出 UI、交互、状态、副作用、数据读写、错误/空状态差异。
7. 未确认清单：凡是没有 Electron 源码或运行证据支撑的结论，都放到这里，不能进入实现。

实现前的输出至少包含：

- 已确认依据：Electron 文件/函数/CSS class/调用点/截图或运行行为。
- Flutter 差异：当前 Flutter 文件/函数/调用点和具体偏差。
- 未确认项：缺哪些 Electron 证据、为什么不能改。
- 本次只改：明确列出要改的已确认差异。
- 本次不改：明确列出未确认项和无关项。

### 业务逻辑对齐规则

- 每个 Flutter 业务改动都必须能对应到 Electron 的文件、函数、调用链或状态流。
- 必须查清点击、菜单、快捷入口、状态变化、数据读写、service/repository 调用和副作用。
- 如果 Electron 使用共享 helper（例如菜单项、命令栏、播放列表操作），Flutter 必须优先复用或镜像同一层级的共享结构，而不是在单个页面手写相似逻辑。
- 如果 Electron 某个分支、异常、空状态、禁用态没有查到，不要补；标为未确认。
- 不要连续或循环请求数据库；需要数据时遵循现有 repository/model 的数据流。

### UI 像素级对齐规则

- CSS、尺寸、颜色、间距、圆角、字体、hover/pressed/selected/disabled/open 状态必须从 Electron 源码和实际渲染中提取。
- 涉及 UI 的任务必须保存或说明 Electron 与 Flutter 的对比截图；仅凭代码相似不能算完成。
- 必须使用相同主题、窗口尺寸、数据状态和交互状态对比。
- Flutter 控件默认样式不可信；必须显式核对它是否等同 Electron。
- 如果截图显示仍有差异，不准说“已对齐”；只能说剩余差异是什么。

### 完成标准

只有同时满足以下条件，才能报告完成：

1. Electron 依据完整且可追溯。
2. Flutter 改动只覆盖已确认差异。
3. UI 任务有运行截图或等价可视化验证。
4. 业务任务有调用链、状态变化或测试验证。
5. 未确认项被明确列出，没有被悄悄实现。

### 开发要求，
1. 当一个类超过800行时要考虑拆分组件。
2. 类名和原版尽可能保持一致。