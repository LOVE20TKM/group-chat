# ABI / 事件 / 错误

准确签名以 `src/interfaces/IGroupChat.sol` 为准。本文件用于 review 分组。

## 主接口

生命周期：

- `LOVE20_GROUP`
- `GROUP_DEFAULTS`
- `originBlocks`
- `phaseBlocks`
- `MAX_CONTENT_LENGTH`
- `MAX_MENTIONS`
- `activateChat`
- `deactivateChat`
- `chatInfo`

Meta：

- `setMeta`
- `setMetaBatch`
- `metaValue`
- `metaEntries`

Delegate：

- `setDelegateGroupId`
- `delegateGroupIdOf`

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
- `GROUP_DEFAULTS`

Query：

- `currentRound`
- `messagesCount`
- `message`
- `messagesByRoundCount`
- `messagesBySenderCount`
- `senderGroupIdsCount`
- `chatGroupIdsCount`
- `activeChatGroupIdsCount`
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
- `senderGroupIds`
- `chatGroupIds`
- `activeChatGroupIds`
- `roundsCount`
- `rounds`
- `roundInfo`

## 结构体

`ChatInfo`：

- `groupId`
- `owner`
- `active`
- `configVersion`
- `firstActivatedOwner`
- `firstActivatedBlockNumber`
- `firstActivatedTimestamp`

`Message`：

- `chatGroupId`
- `senderGroupId`
- `senderAddress`
- `round`
- `messageId`
- `content`
- `blockNumber`
- `timestamp`
- `mentions`
- `mentionAll`
- `quotedMessageId`：`0` 表示无引用，非零时指向当前 chat 内 1-based `messageId`

`RoundSpan`：

- `round`
- `startMessageId`：该 round 首条消息的 `messageId`；空 round 返回 `0`
- `endMessageId`：该 round 末尾后一位的 `messageId`；空 round 返回 `0`
- `messageCount`

`MetaEntry`：

- `key`
- `value`

## 事件

配置事件：

- `ChatActivate`
- `ChatDeactivate`
- `MetaSet`
- `DelegateGroupIdSet`
- `ScopeSourceSet`
- `DenySourceSet`
- `BeforePostPluginSet`
- `AfterPostPluginSet`

消息事件：

- `MessagePost`
- `AfterPostPluginFailed`

默认身份注册表事件：

- `SetDefaultGroupId`
- `ClearDefaultGroupId`

事件规则：

- 同一笔配置写的所有差异事件必须携带同一个新 `configVersion`。
- `ChatActivate` 在同笔交易内所有配置差异事件之后发出。
- `MessagePost` 必须先于 `afterPostPlugin` 调用。
- `afterPostPlugin` 失败只发 `AfterPostPluginFailed`，不回滚消息。

## 错误

核心错误：

- `GroupNotExist`
- `ChatAlreadyActive`
- `ChatAlreadyInactive`
- `ChatNotActive`
- `NotChatOwner`
- `NotChatOwnerOrDelegateGroupOwner`
- `SenderNotGroupOwner`
- `RoundNotStarted`
- `PhaseBlocksZero`

Meta 错误：

- `MetaKeyEmpty`
- `MetaArrayLengthMismatch`
- `DuplicateMetaKey`
- `MetaValueUnchanged`
- `MetaKeyNotFound`

Delegate 错误：

- `DelegateGroupIdCannotBeChatGroupId`
- `DelegateGroupIdUnchanged`

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
- `TooManyMentions`
- `DuplicateMentionGroupId`
- `InvalidQuotedMessageId`
- `InvalidMessageId`

默认身份错误：

- `DefaultGroupIdNotSet`
- `GroupDefaultsHasNoCode`
