# Everclip

Everclip 是一个为 macOS 设计的菜单栏剪贴板工具。它会在后台记录文本和图片剪贴内容，并提供快速搜索、预览、置顶收藏和快捷粘贴能力。

## 功能

- 菜单栏常驻运行，不占用 Dock 空间
- 自动捕获剪贴板文本和图片
- 支持图片预览和再次粘贴
- `Command + Shift + V` 打开快速粘贴浮窗
- 历史记录搜索、分组折叠、置顶收藏
- 单条删除和一键清空历史
- 日间、夜间、跟随系统外观
- 首次启动引导和独立设置窗口

## 权限

自动粘贴需要 macOS 辅助功能权限。首次使用快速粘贴时，如果没有授权，Everclip 会请求权限。

也可以手动打开：

`系统设置 -> 隐私与安全性 -> 辅助功能`

然后将 Everclip 添加并勾选。

## 运行

使用 Xcode 打开 `everclip.xcodeproj`，选择 `everclip` scheme 后运行即可。

命令行构建：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project everclip.xcodeproj -scheme everclip -destination platform=macOS -derivedDataPath /private/tmp/everclip-derived CODE_SIGNING_ALLOWED=NO build
```
