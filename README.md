# TranslatePlugin V1

保守型 WhatsApp UI 增强 dylib：输入框旁“译”按钮、长按可见文本翻译/复制、OpenAI-compatible API 设置。翻译仅回填，绝不自动发送。

## 构建

需要 macOS + Xcode Command Line Tools + Theos：

```sh
export THEOS=~/theos
make clean package FINALPACKAGE=1
```

产物位于 `.theos/obj/debug/TranslatePlugin.dylib`（普通构建）或先从 `.deb` 的 `Library/MobileSubstrate/DynamicLibraries/TranslatePlugin.dylib` 解包。注入 IPA 时将 dylib 放入 `WhatsApp.app/Frameworks/`，用 insert_dylib/optool 写入加载命令，再对整个 app 重新签名。

首次启动会弹设置页。之后如需重设，可删除插件 Keychain 项/偏好后重启（后续版本会加入固定设置入口）。

> WhatsApp 私有 UI 随版本变化。本实现只做运行时通用 UI 扫描并在失败时降级；请使用测试账号，自行承担第三方客户端修改带来的账号与稳定性风险。
