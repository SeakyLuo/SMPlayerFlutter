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