# TranslatePlugin V3

WhatsApp 内嵌翻译插件：仅扫描当前聊天页可见消息 Cell，默认只翻译对方外语消息并在原文下方显示简体中文；在 WhatsApp 右下角 Settings/You 页追加“翻译插件设置”入口。支持 OpenAI-compatible/DeepSeek、自定义接口、超时重试、术语库、持久化缓存、深色模式和调试日志。绝不自动发送或修改原始消息。

## 构建

需要 macOS + Xcode Command Line Tools + Theos：

```sh
export THEOS=~/theos
make clean package FINALPACKAGE=1
```

产物位于 `.theos/obj/debug/TranslatePlugin.dylib`（普通构建）或先从 `.deb` 的 `Library/MobileSubstrate/DynamicLibraries/TranslatePlugin.dylib` 解包。注入 IPA 时将 dylib 放入 `WhatsApp.app/Frameworks/`，用 insert_dylib/optool 写入加载命令，再对整个 app 重新签名。

首次使用请进入 WhatsApp 右下角 Settings/You 页面，点击列表底部“翻译插件设置”配置 Base URL、API Key 与 Model Name。

> WhatsApp 私有 UI 随版本变化。本实现只做运行时通用 UI 扫描并在失败时降级；请使用测试账号，自行承担第三方客户端修改带来的账号与稳定性风险。
