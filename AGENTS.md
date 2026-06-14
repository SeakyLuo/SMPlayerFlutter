# Project Notes

- Original UWP project for parity checks: `C:\Users\luoki\source\repos\SMPlayer\SMPlayer`
- Electron reference project: `C:\Users\luoki\Desktop\Projects\Electron\SMPlayer` / `/Users/luohaitian/Desktop/Projects/SMPlayerElectron`
- Current project: Flutter migration for Win/Mac/Android/Flutter.

默认开发规则：

1. 如果用户没有明确要求“参考 Electron / 原版 / 对齐 / parity / 迁移 / 一模一样”，不要默认查 Electron，也不要把 Electron 当成当前改动的唯一标准。
2. 用户可能会做一些和 Electron 不同的 Flutter 优化；这种情况下以用户当前要求、现有 Flutter 代码结构、现有设计语言和测试为准。
3. 不要自行编造业务逻辑或 UI 规则。需求不明确时先从当前 Flutter 实现和用户描述推导，仍无法确定再说明不确定点。
4. 禁止为了兼容不可能发生的输入做防御性编程、normalize 或空校验。
5. 禁止随意 fallback 兜底、临时修复/workaround 绕过问题，除非获得用户同意。
6. 前端不要主动显示 ID，不要让用户填写 ID，不要暴露调试信息或开发信息。
7. 可能同时有多个 AI 在开发；不是你本次改动导致的编译不通过或无关 dirty changes，除非用户明确要求，可以不用管，也不要回滚。
8. 不要连续或循环请求数据库；需要数据时遵循现有 repository/model 的数据流。

## Electron 对齐规则

只有当用户明确要求“参考 Electron / 原版 / 对齐 / parity / 迁移 / 一模一样”等目标时，才读取并遵循：

- `docs/electron_migration_rules.md`

未触发这些关键词时，不要读取该文件，也不要套用 Electron 对齐流程。

## 开发要求

1. 当一个类超过 800 行时要考虑拆分组件。
2. 普通 Flutter 优化不强制按 Electron 命名；只有 Electron 对齐任务才需要参考原版命名。
