# 发言与查询

## 发言身份

发消息必须同时指定：

- `chatGroupId`：消息落到哪个 chat
- `senderGroupId`：用哪个 `GroupNFT` 身份发言

要求：

- `msg.sender` 必须是 `senderGroupId` 当前 owner。
- `senderGroupId` 可与 `chatGroupId` 不同。
- `senderGroupId` 自己的 chat 不要求已激活。
- delegate 不能冒充 `senderGroupId` 发言。

## 发言校验

普通 `post` 校验顺序：

```text
chat active
senderGroupId exists
senderAddress owns senderGroupId
content / mentions / quote core validation
scopeSource.canPost
denySource.isDenied
beforePostPlugin.beforePost
write message
afterPostPlugin.afterPost
```

`canPost(...)` 只做无内容预检查：

- active
- sender owner
- `scopeSource`
- `denySource`

`canPost(...)` 不检查：

- `content`
- `mentions`
- `mentionAll`
- `quotedMessageIndex`
- `beforePostPlugin`

`canPostStatus(...)` reasonCode：

```text
0x00000000                         OK
ChatNotActive.selector             chat 未激活
GroupNotExist.selector             chatGroupId 或 senderGroupId 不存在
SenderNotGroupOwner.selector       senderAddress 不是 senderGroupId 当前 owner
ScopeRejected.selector             scopeSource 判定无资格
DenyRejected.selector              denySource 判定被拒绝
ScopeSourceFailed.selector         scopeSource 调用失败
DenySourceFailed.selector          denySource 调用失败
```

## 消息内容

- `content` 类型为 `string`。
- 空消息必须 revert。
- 单条消息上限固定为 `16384` bytes。
- 消息只能新增，不能编辑或删除。
- `MessagePost` 事件不带完整正文，正文以 view 读取为准。

## Mentions

- `mentions` 是 `uint256[]`。
- 上限固定为 `32`。
- 每个 `mentionedGroupId` 必须存在。
- 不允许重复。
- 允许提及自己。
- `mentionAll` 只记录声明语义，主协议不做许可判断。

## 引用

- `quotedMessageIndex == 0` 表示无引用。
- `quotedMessageIndex > 0` 必须指向当前 chat 内已存在消息。
- 协议不支持引用 `messageIndex == 0`。
- 引用合法性在 source / plugin 调用前校验。

## 默认发言身份

默认身份由 `GroupDefaults` 维护：

- `setDefaultGroupId(groupId)`
- `clearDefaultGroupId()`
- `defaultGroupIdOf(account)`
- `defaultGroupsOf(accounts)`

`postByDefaultSender(...)` 只是在调用前解析当前有效默认身份，然后复用 `post(...)`。

## Round

- `round` 从 `0` 开始。
- `currentRound()` 等于 `roundByBlockNumber(block.number)`。
- `roundByBlockNumber(blockNumber) = (blockNumber - originBlocks) / phaseBlocks`。
- `block.number < originBlocks` 时 `currentRound()` revert。
- 因 `post` 依赖 `currentRound()`，origin 之前不能成功发消息。

## 分页

通用规则：

- `reverse=false`：旧到新。
- `reverse=true`：新到旧。
- `offset` 以最终返回方向为基准。
- `limit == 0` 返回空数组。
- 分页越界返回空数组。

消息查询维度：

- 全量：`messages`
- 按 round：`messagesByRound`
- 按 sender：`messagesBySender`
- 按 mention：`messagesByMention`
- 按 mentionAll：`messagesByMentionAll`

轻量索引：

- `messageIndexesBySender`
- `messageIndexesByMention`
- `messageIndexesByMentionAll`

列表：

- `senderGroupIds`
- `rounds`

## 同步策略

- `MessagePost` 只作为发现信号。
- 正文以 `message(...)` 或 `messages(...)` 为准。
- 前端维护每个 `chatGroupId` 的最新 `messageIndex`。
- 若事件中的 `messageIndex` 出现缺口，按区间补拉。
- 配置变化以 `configVersion` 和 `ruleSlots` / `metaEntries` 重拉为准。
