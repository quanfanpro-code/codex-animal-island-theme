# Codex 狸克手机主题包

这是给 Windows 原版 Codex 加的一层动森风格界面皮肤。

它只改变原版 Codex 已经显示出来的界面，不读取、不复制、不迁移账号、任务、项目、设置或聊天数据，也不修改微软商店里的 Codex 安装文件。

## 安装

1. 解压整个主题包。
2. 双击“安装狸克手机主题.cmd”。
3. 如果 Codex 正在运行，按提示正常关闭一次。
4. 以后双击桌面的“Codex 狸克手机”即可带皮肤启动；从原 Codex 图标启动仍是原界面。

安装不需要管理员权限，也不需要 Node 或 Python；需要 PowerShell 7。主题会自动寻找这台 Windows 电脑上最新的微软商店版 Codex。

## 主题内容

- C「狸克手机」原稿的奶油色侧栏、蓝绿色岛屿波浪和青绿菜单强调
- 清晰可见的绿色三角纹主屏与适度圆角
- 奶油色内容卡与输入框
- 暖棕色文字、青绿色按钮、少量黄色强调
- 狸克角色水印、叶片装饰和网站原分隔线

全部图像素材来自 animal-island-ui 项目的固定版本，来源与哈希见 `sources.lock.json`。

## 开源说明

本项目是非官方主题，与 OpenAI、Nintendo 及 animal-island-ui 作者无官方关联。完整源码包括 `skin/`、`tools/`、`runtime/`、`installer/` 和 `tests/`。

- 构建：`pwsh -NoProfile -File tools/build-runtime-mod.ps1`
- 测试：`node --test tests/runtime-mod.test.mjs`
- 下载：[GitHub Releases](https://github.com/quanfanpro-code/codex-animal-island-theme/releases)

本项目沿用上游 CC BY-NC 4.0，必须保留署名和修改说明，仅限非商业使用。详情见 `LICENSE` 和 `NOTICE.md`。
