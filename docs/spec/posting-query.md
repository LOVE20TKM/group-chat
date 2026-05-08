# 发言与查询

## 发言身份

发消息必须同时指定：

- `chatGroupId`：消息落到哪个 chat
- `senderId`：用哪个 `GroupNFT` 身份发言

命名约定：

- `senderId` 永远表示发言身份 NFT 的 `tokenId`
- 地址语义必须显式命名为 `senderAddress`

要求：

- `msg.sender` 必须是 `senderId` 当前 owner。
- `senderId` 可与 `chatGroupId` 不同。
- `senderId` 自己的 chat 不要求已激活。
- delegate 不能冒充 `senderId` 发言。

## 发言校验

普通 `post` 校验顺序：

```text
chatGroupId exists
chat active
senderId exists
senderAddress owns senderId
content / mentionedSenderIds / quote core validation
currentRound
scopeSource.canPost
denySource.isDenied
beforePostPlugin.beforePost
write message
afterPostPlugin.afterPost
```

`canPost(...)` 只做无内容预检查：

- chatGroupId exists
- active
- senderId exists
- sender owner
- `scopeSource`
- `denySource`

`canPost(...)` 不检查：

- `content`
- `mentionedSenderIds`
- `mentionAll`
- `quotedMessageId`
- `beforePostPlugin`

`canPostStatus(...)` reasonCode：

```text
0x00000000                         OK
ChatNotActive.selector             chat 未激活
GroupNotExist.selector             chatGroupId 或 senderId 不存在
SenderAddressNotSenderIdOwner.selector       senderAddress 不是 senderId 当前 owner
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

## 消息 ID

- 每条消息的 `messageId` 只在当前 `chatGroupId` 内唯一。
- `messageId` 从 `1` 开始连续递增。
- `0` 永远不分配给消息，只保留给“无引用”。
- `messageId = messageIndex + 1`，其中 `messageIndex` 只表示合约内部数组下标。
- `message(chatGroupId, messageId)` 的 `messageId` 必须是 `1..messagesCount(chatGroupId)`。

## Mentioned Sender IDs

- `mentionedSenderIds` 是 `uint256[]`。
- 上限固定为 `32`。
- 每个 `mentionedSenderId` 必须存在。
- 不允许重复。
- 允许提及自己。
- `mentionAll` 只记录声明语义，主协议不做许可判断。

## 引用

- `quotedMessageId == 0` 表示无引用。
- `quotedMessageId > 0` 必须指向当前 chat 内已存在的 `messageId`。
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
- `phaseBlocks` 必须大于 `0`，否则部署无效。
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
- 按 round：`roundInfo` / `roundInfos` / `rounds` 返回该 round 首尾 `messageId` 与消息数；`messagesByRound` 是直接取消息的便利接口
- 按 sender：`messagesBySender`
- 按 mention：`messagesByMention`
- 按 mentionAll：`messagesByMentionAll`

轻量索引：

- `messageIdsBySender`
- `messageIdsByMention`
- `messageIdsByMentionAll`

列表：

- `senderIds`
- `rounds`

批量 round 区间：

- `roundInfos(chatGroupId, roundIds)` 按入参顺序返回 `RoundSpan[]`。
- 不存在或无消息的 round 返回 `round = 入参`、`startMessageId = 0`、`endMessageId = 0`、`messageCount = 0`。

群发现：

- `chatGroupIdsCount` / `chatGroupIds`：所有曾首次激活过的 `chatGroupId`，按首次激活顺序分页。
- `activeChatGroupIdsCount` / `activeChatGroupIds`：当前 `active` 的 `chatGroupId` 集合；关闭会移除，重开会重新加入 active 集合。

## 同步策略

- `MessagePost` 只作为发现信号。
- `MessageMention` / `MessageMentionAll` 只作为链下通知索引信号。
- 正文以 `message(...)` 或 `messages(...)` 为准。
- 前端维护每个 `chatGroupId` 的最新 `messageId`。
- 若事件中的 `messageId == latestMessageId + 1`，可用 `message(chatGroupId, messageId)` 回查。
- 若事件中的 `messageId > latestMessageId + 1`，用 `messages(chatGroupId, latestMessageId, messageId - latestMessageId, false)` 补拉缺口。
- 配置变化以 `configVersion` 和 `ruleSlots` / `metaEntries` 重拉为准。
