# 发言与查询

## 发言身份

发消息必须同时指定：

- `groupId`：消息落到哪个 chat
- `senderId`：用哪个 `GroupNFT` 身份发言

命名约定：

- `senderId` 永远表示发言身份 NFT 的 `tokenId`
- 地址语义必须显式命名为 `senderAddress`

要求：

- `msg.sender` 必须是 `senderId` 当前 owner。
- `senderId` 可与 `groupId` 不同。
- `senderId` 自己的 chat 不要求已激活。
- delegate 不能冒充 `senderId` 发言。

## 发言校验

普通 `post` 校验顺序：

```text
groupId exists
chat activated
posting allowed
senderId exists
senderAddress owns senderId
content / mentionedSenderIds / quote core validation
currentRound
owner/delegate bypasses source checks
scopeSource.canPost
banSource.isBanned
beforePostPlugin.beforePost
write message
afterPostPlugin.afterPost
```

若 `senderAddress` 命中 `GroupDelegate.ownerOrDelegateIdOf(groupId, senderAddress)`，则在完成群存在、激活、发言开关、`senderId` 存在与 `senderAddress owns senderId` 等核心校验后，跳过 `scopeSource` 与 `banSource`。owner / delegate 仍不能冒充不属于自己的 `senderId` 发言。

`canPost(...)` 只做无内容预检查：

- groupId exists
- activated
- postingAllowed
- senderId exists
- sender owner
- owner / delegate source bypass
- 非 owner / delegate：`scopeSource`
- 非 owner / delegate：`banSource`

`canPost(...)` 不检查：

- `content`
- `mentionedSenderIds`
- `mentionAll`
- `quotedMessageId`
- `beforePostPlugin`

`canPost(...)` 返回 `(allowed, reasonCode)`：

```text
0x00000000                         OK
ChatNotActivated.selector          chat 未激活
PostingNotAllowed.selector         chat 已停止发言
GroupNotExist.selector             groupId 或 senderId 不存在
SenderAddressNotSenderIdOwner.selector       senderAddress 不是 senderId 当前 owner
ScopeRejected.selector             scopeSource 判定无资格
BanRejected.selector              banSource 判定被拒绝
ScopeSourceFailed.selector         scopeSource 调用失败
BanSourceFailed.selector          banSource 调用失败
```

## 消息内容

- `content` 类型为 `string`。
- 空消息必须 revert。
- 单条消息上限固定为 `4096` bytes。
- 消息只能新增，不能编辑或删除。
- `PostMessage` 事件不带完整正文，正文以 view 读取为准。

## 消息 ID

- 每条消息的 `messageId` 只在当前 `groupId` 内唯一。
- `messageId` 从 `1` 开始连续递增。
- `0` 永远不分配给消息，只保留给“无引用”。
- `messageId = messageIndex + 1`，其中 `messageIndex` 只表示合约内部数组下标。
- `message(groupId, messageId)` 的 `messageId` 必须是 `1..messagesCount(groupId)`。

## Mentioned Sender IDs

- `mentionedSenderIds` 是 `uint256[]`。
- 上限固定为 `32`。
- 每个 `mentionedSenderId` 必须存在。
- 不允许重复。
- 允许提及自己。
- `mentionAll` 只能由群 owner、delegate 或 admin 发出，普通发言者会被 `MentionAllUnauthorized` 拒绝。
- 当前存在性校验依赖 `LOVE20Group` 的 `tokenId` 从 `1` 连续铸造且不 burn；若上游改成非连续或可 burn，必须改为 `ownerOf` 校验。

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

`postAsDefaultSender(...)` 只是在调用前解析当前有效默认身份，然后复用 `post(...)`。

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

批量 chat 配置：

- `chatInfos(groupIds)` 按入参顺序返回 `ChatInfo[]`，单项语义与 `chatInfo(groupId)` 一致。

批量 round 区间：

- `roundInfos(groupId, rounds)` 按入参顺序返回 `RoundSpan[]`。
- 不存在或无消息的 round 返回 `round = 入参`、`startMessageId = 0`、`endMessageId = 0`、`messageCount = 0`。

群发现：

- `groupIdsCount` / `groupIds`：所有曾首次激活过的 `groupId`，按首次激活顺序分页。

## 同步策略

- `PostMessage` 只作为发现信号。
- `MentionSenderId` / `MentionAll` 只作为链下通知索引信号。
- 正文以 `message(...)` 或 `messages(...)` 为准。
- 前端维护每个 `groupId` 的最新 `messageId`。
- 若事件中的 `messageId == latestMessageId + 1`，可用 `message(groupId, messageId)` 回查。
- 若事件中的 `messageId > latestMessageId + 1`，用 `messages(groupId, latestMessageId, messageId - latestMessageId, false)` 补拉缺口。
- 配置变化以配置事件为信号，并通过 `chatInfo` / `chatInfos` 与各规则槽 view 重拉当前状态。
