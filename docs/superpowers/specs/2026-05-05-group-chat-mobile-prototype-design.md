# GroupChat 移动端交互原型设计

## 目标

基于当前 `group-chat` 合约与文档，设计一个可交互前端原型，用于验证普通用户在手机上使用 LOVE20 链上群聊的核心闭环。

首要场景：

1. 用户进入某个 `GroupNFT` 对应的 chat。
2. 前端显示微信式聊天界面。
3. 用户选择或使用默认 `senderGroupId`。
4. 前端展示 `canPostStatus`、`scopeSource`、`denySource` 等链上状态。
5. 用户读取消息、引用消息、提及身份、发送公开链上消息。
6. 桌面端同一路由保持手机优先预览，不额外引入宽屏分栏。

## 设计原则

- 交互布局仿照微信聊天：顶部群名、消息气泡、底部输入栏、顶部 `...` 群菜单。
- 视觉样式参考 `../interface-test`：白底、slate 灰阶、primary / secondary 色系、8px 圆角、轻边框、紧凑移动端卡片。
- 不复刻微信品牌元素；自己消息气泡和主按钮使用当前原型的 primary / secondary 色系。
- 手机为主，桌面为居中预览增强。
- 协议状态服务于用户判断，不做 ABI 控制台。
- 不复刻微信品牌元素、图标或专有视觉资产，只复用通用聊天交互范式。

## 范围

### 包含

- 聊天列表入口与当前 chat 头部。
- 消息流：普通消息、自己消息、引用消息、mentions、mentionAll 标识。
- 底部输入栏：内容输入、引用 chip、发送按钮；`@姓名` 与 `@全部` 由输入框文本自动解析。
- 长按消息菜单：引用、提及、复制 `messageIndex`。
- 顶部 `...` 群菜单：详情、黑名单、豁免名单、管理入口。
- 不可发言状态：显示标准错误 selector 对应中文原因。
- 桌面自适应：居中手机壳预览，保持同一移动端交互。

### 不包含

- 私聊。
- 消息编辑、删除、撤回。
- 协议外阅读权限。
- 完整 AdminDenySource 或 GovVotedDenySource 后台。
- 真实钱包交易接入。原型只模拟交互与状态。

## 协议映射

| UI 能力 | 合约/文档依据 |
| --- | --- |
| chat 身份 | `1 NFT = 1 Chat`，`chatGroupId == GroupNFT.tokenId` |
| 头部状态 | `chatInfo(groupId)`：`active`、`owner`、`configVersion` |
| 默认发言身份 | `GroupDefaults.defaultGroupIdOf(account)` |
| 发送消息 | `post` / `postByDefaultSender` |
| 可发言判断 | `canPostStatus(chatGroupId, senderGroupId, senderAddress)` |
| 错误原因 | `ChatNotActive`、`SenderNotGroupOwner`、`ScopeRejected`、`DenyRejected` 等 selector |
| 引用 | `quotedMessageIndex`，`0` 表示无引用 |
| 提及 | `mentions uint256[]`，最大 `32`，去重 |
| 全体提及 | `mentionAll`，只记录声明语义 |
| 消息同步 | `MessagePost` 只做发现信号，正文用 `message/messages` 回查 |
| 消息分页 | `messages`、`messagesByRound`、`messagesBySender`、`messagesByMention`、`messagesByMentionAll` |
| 规则槽 | `ruleSlots(groupId)`：`scopeSource`、`denySource`、`beforePostPlugin`、`afterPostPlugin` |

## 信息架构

### 移动端

1. 顶部栏
   - 返回按钮。
   - 群名：`群聊 #<chatGroupId>`。
   - 副标题：群类型、成员/消息摘要。
   - `...` 打开群菜单。

2. 消息区
   - 灰色背景。
   - 他人消息左侧头像，白色气泡。
   - 自己消息右侧头像，secondary 浅色气泡。
   - 每条消息显示 `senderGroupId`、`messageIndex`、必要时显示 `round`。
   - 引用消息在气泡内用小引用块展示。

3. 状态条
   - 靠近输入区显示同步提示和模拟交易反馈。
   - 示例：`MessagePost 发现 messageIndex #80，正文已通过 messages 补拉。`
   - 发言资格失败时由不可发言输入区展示标准 selector 对应中文原因。

4. 输入区
   - 引用 chip 显示在输入框上方。
   - 引用草稿按 `chatGroupId` 隔离，切换群聊不会串用其他群的 `quotedMessageIndex`。
   - 输入框字号至少 `16px`，避免移动端浏览器自动缩放。
   - 用户直接输入 `@姓名` 生成 `mentions`，直接输入 `@全部` 生成 `mentionAll=true`。
   - 长按头像可把对应 `@姓名` 插入输入框。
   - 点击头像时，若当前地址默认 NFT 是该 chat 的管理员 NFT，则弹出拉黑 sender 菜单。
   - 发送按钮触发模拟 `post`。

5. `...` 群菜单与详情页
   - 详情页展示当前 `senderGroupId` 与不可发言原因。
   - 管理页展示 `scopeSource` / `denySource` / plugin。
   - 黑名单页展示治理禁言或管理员禁言状态。

### 桌面端

- 同一路由宽屏下保持手机壳预览。
- 手机壳居中展示，不展开左侧群列表或右侧状态栏。
- 详情、黑名单、管理仍通过群菜单进入独立页面。

## 交互状态

原型至少模拟：

- 正常可发言。
- `ScopeRejected`：无发言资格。
- `DenyRejected`：被黑名单拒绝。
- `SenderNotGroupOwner`：当前钱包不是 `senderGroupId` owner。
- 引用某条消息后发送。
- 输入框自动解析 mention 与 mentionAll。
- 从 `MessagePost` 发现缺口后补拉区间的提示。

## 组件边界

- `ChatShell`：手机优先布局容器。
- `ChatHeader`：移动端顶部栏。
- `ChatList`：聊天列表入口。
- `MessageList`：消息渲染和分页状态。
- `MessageBubble`：气泡、引用、mention 标记、长按菜单。
- `Composer`：输入栏、引用 chip、自动解析 `@姓名` / `@全部`、发送按钮。
- `GroupMenu`：详情、黑名单、豁免名单、管理入口。
- `GroupDetails`：当前身份、`canPostStatus` 和错误原因。
- `MockProtocolState`：原型用 mock 数据和状态切换。

## 测试与验收

- 手机宽度约 `390px` 下：
  - 文本不溢出。
  - 输入栏不遮挡消息。
  - 顶部 `...` 可打开群菜单。
  - 长按菜单或点击菜单可完成引用。
  - 发送后新消息出现在消息流。

- 桌面宽度约 `1280px` 下：
  - 手机壳居中显示。
  - 消息区仍使用同一气泡组件。
  - 不出现嵌套卡片堆叠。

- 协议覆盖：
  - `canPostStatus` reasonCode 能在 UI 中解释。
  - `mentions` 上限和去重有前端提示。
  - `quotedMessageIndex` 为 `0` 与非 `0` 两种状态可见。
  - `MessagePost` 事件不是正文真源的同步策略在 UI 中有提示。

## 原型交付

优先在当前 `group-chat` 仓库内新增独立静态原型，避免改动相邻 `interface-test` 生产前端。

建议路径：

- `prototype/group-chat/index.html`
- `prototype/group-chat/styles.css`
- `prototype/group-chat/app.js`

打开方式：

- 静态文件可直接浏览器打开。
- 如需本地服务，用 `python3 -m http.server` 从 `prototype/group-chat` 启动。

## 已确认决策

- 布局交互仿微信。
- 样式参考 `interface-test`。
- 手机是主要使用场景。
- 桌面端做自适应，不作为主设计。
