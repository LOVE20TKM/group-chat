# ABI / 事件 / 错误

准确签名以 `src/interfaces/IGroupChat.sol` 为准。本文件用于 review 分组。

## 主接口

生命周期：

- `LOVE20_GROUP_ADDRESS`
- `GROUP_DEFAULTS_ADDRESS`
- `originBlocks`
- `phaseBlocks`
- `MAX_CONTENT_LENGTH`
- `MAX_MENTIONED_SENDER_IDS`
- `activateChat`
- `setPostingAllowed`
- `chatInfo`

Meta：

- `setMeta`
- `setMetaBatch`
- `metaValue`
- `metaEntries`

Delegate：

- `setDelegateId`
- `delegateIdOf`

Rule slots：

- `setScopeSource`
- `setDenySource`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- `scopeSource`
- `denySource`
- `beforePostPlugin`
- `afterPostPlugin`
- `ruleSlots`
- `canPost`
- `canPostStatus`

Posting：

- `post`
- `postByDefaultSender`
- `GROUP_DEFAULTS_ADDRESS`

Query：

- `currentRound`
- `messagesCount`
- `message`
- `messagesByRoundCount`
- `messagesBySenderCount`
- `senderIdsCount`
- `chatGroupIdsCount`
- `messages`
- `messagesByRound`
- `messagesBySender`
- `messagesByMentionCount`
- `messagesByMention`
- `messagesByMentionAllCount`
- `messagesByMentionAll`
- `messageIdsBySender`
- `messageIdsByMention`
- `messageIdsByMentionAll`
- `senderIds`
- `chatGroupIds`
- `roundsCount`
- `rounds`
- `roundInfo`
- `roundInfos`

## 结构体

`ChatInfo`：

- `chatGroupId`
- `owner`
- `activated`
- `postingAllowed`
- `configVersion`
- `firstActivatedOwner`
- `firstActivatedBlockNumber`
- `firstActivatedTimestamp`

`Message`：

- `chatGroupId`
- `senderId`
- `senderAddress`
- `round`
- `messageId`
- `content`
- `blockNumber`
- `timestamp`
- `mentionedSenderIds`
- `mentionAll`
- `quotedMessageId`：`0` 表示无引用，非零时指向当前 chat 内 1-based `messageId`

`RoundSpan`：

- `round`
- `startMessageId`：该 round 首条消息的 `messageId`；空 round 返回 `0`
- `endMessageId`：该 round 最后一条消息的 `messageId`；空 round 返回 `0`
- `messageCount`

`metaEntries` 返回：

- `keys`
- `values`
- 同一索引的 `keys[i]` 与 `values[i]` 对应

## 事件

配置事件：

- `ChatActivate`
- `PostingAllowedSet`
- `MetaSet`
- `DelegateIdSet`
- `ScopeSourceSet`
- `DenySourceSet`
- `BeforePostPluginSet`
- `AfterPostPluginSet`

消息事件：

- `MessagePost`
- `MessageMention(uint256 indexed chatGroupId, uint256 indexed mentionedSenderId, uint256 messageId)`
- `MessageMentionAll(uint256 indexed chatGroupId, uint256 messageId)`
- `AfterPostPluginFailed`

默认身份注册表事件：

- `SetDefaultGroupId`
- `ClearDefaultGroupId`

事件规则：

- 同一笔配置写的所有差异事件必须携带同一个新 `configVersion`。
- `ChatActivate` 在同笔交易内所有配置差异事件之后发出。
- `MessagePost` 必须先于 `afterPostPlugin` 调用。
- `MessageMention` / `MessageMentionAll` 是链下通知索引信号，必须在 `MessagePost` 之后、`afterPostPlugin` 之前发出。
- `afterPostPlugin` 失败只发 `AfterPostPluginFailed`，不回滚消息。

## 错误

核心错误：

- `GroupNotExist`
- `ChatAlreadyActivated`
- `ChatNotActivated`
- `PostingNotAllowed`
- `PostingAllowedUnchanged`
- `NotChatOwner`
- `NotChatOwnerOrDelegateIdOwner`
- `SenderAddressNotSenderIdOwner`
- `RoundNotStarted`
- `PhaseBlocksZero`

Meta 错误：

- `MetaKeyEmpty`
- `MetaArrayLengthMismatch`
- `DuplicateMetaKey`
- `MetaValueUnchanged`
- `MetaKeyNotFound`

Delegate 错误：

- `DelegateIdCannotBeChatGroupId`
- `DelegateIdUnchanged`

Rule slot 错误：

- `PluginAddressHasNoCode`
- `PluginAddressUnchanged`
- `ScopeRejected`
- `DenyRejected`
- `ScopeSourceFailed`
- `DenySourceFailed`

消息错误：

- `ContentEmpty`
- `ContentTooLong`
- `TooManyMentionedSenderIds`
- `DuplicateMentionedSenderId`
- `InvalidQuotedMessageId`
- `InvalidMessageId`

默认身份错误：

- `DefaultGroupIdNotSet`
- `GroupDefaultsHasNoCode`
