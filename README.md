# 浮浮
浮浮是一款 macOS 桌面宠物应用。它可以在桌面上常驻一只可互动的小宠物，支持上传自定义九行动作素材、点击聊天、本地管理宠物和接入 MiniMax/Anthropic 兼容格式的大模型接口。
## 下载
最新版本可以在 Release 页面下载：
[下载 fufu-v0.1.0.zip](https://github.com/SZKujo/fufu/releases/tag/v0.1.0)
下载后解压 `fufu-v0.1.0.zip`，得到 `浮浮.app`。
如果 macOS 首次打开时提示无法验证开发者，可以右键点击 `浮浮.app`，选择“打开”。
## 当前能力
- 创建自定义桌宠
- 上传九行动作 spritesheet 素材
- 选择或取消当前展示宠物
- 桌宠置顶悬浮，支持跨桌面和全屏空间展示
- 支持悬停、点击、拖动、思考、回复等动作状态
- 点击桌宠打开聊天气泡
- 本地假智能回复模式
- MiniMax/Anthropic 兼容接口配置
- 主界面查看聊天历史
- 宠物数据、本地素材和聊天记录保存在本机
## 系统要求
- macOS 14 或更高版本
- Apple Silicon Mac 优先测试
## 素材格式
自定义宠物目前只支持九行动作 spritesheet。每一行代表一种动作，系统会按行从左到右解析透明背景上的帧。
九行动作规则：
1. 默认待机动作
2. 向右拖动动作
3. 向左拖动动作
4. 刚唤醒/打招呼动作
5. 鼠标悬停动作
6. 回复出错动作
7. 回复完成动作
8. 问题思考中动作
9. 回复中动作
推荐使用透明背景的 WebP/PNG spritesheet，尽量保证每一行动作数量合理，角色轮廓清晰。
## 大模型配置
应用支持两种聊天模式：
- 假智能模式：完全本地运行，不需要 API Key
- 真智能模式：通过 MiniMax/Anthropic 兼容接口请求模型
MiniMax 推荐配置：
```bash
ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic
ANTHROPIC_API_KEY=你的 API Key
