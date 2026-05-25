# ABI / 事件 / 错误

准确签名以 `src/interfaces/IGroupChat.sol` 为准。本文件用于 review 分组。

## 主接口

生命周期：

- `GROUP_ADDRESS`
- `GROUP_ADMIN_ADDRESS`
- `GROUP_DEFAULTS_ADDRESS`
- `GROUP_DELEGATE_ADDRESS`
- `originBlocks`
- `phaseBlocks`
- `MAX_CONTENT_LENGTH`
- `MAX_MENTIONED_SENDER_IDS`
- `activateChat`
- `setPostingAllowed`
- `postingAllowed`
- `chatInfo`

Rule slots：

- `setScopeSource`
- `setBanSource`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- `scopeSource`
- `banSource`
- `beforePostPlugin`
- `afterPostPlugin`
- `canPost`

Posting：

- `post`
- `postAsDefaultSender`
- `GROUP_DEFAULTS_ADDRESS`

Query：

- `currentRound`
- `messagesCount`
- `message`
- `messagesByRoundCount`
- `messagesBySenderCount`
- `senderIdsCount`
- `groupIdsCount`
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
- `groupIds`
- `roundsCount`
- `rounds`
- `roundInfo`
- `roundInfos`

## 结构体

`ChatInfo`：

- `groupId`
- `owner`
- `activated`
- `postingAllowed`
- `scopeSource`
- `banSource`
- `beforePostPlugin`
- `afterPostPlugin`
- `firstActivatedOwner`
- `firstActivatedBlockNumber`
- `firstActivatedTimestamp`

`Message`：

- `groupId`
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

## 事件

配置事件：

- `Activate(uint256 indexed groupId, address indexed owner)`
- `SetPostingAllowed`
- `SetScopeSource`
- `SetBanSource`
- `SetBeforePostPlugin`
- `SetAfterPostPlugin`

消息事件：

- `PostMessage`
- `MentionSenderId(uint256 indexed groupId, uint256 indexed mentionedSenderId, uint256 messageId)`
- `MentionAll(uint256 indexed groupId, uint256 messageId)`
- `FailAfterPostPlugin`

Manager 事件：

- `Activate(address indexed token, uint256 indexed groupId, address indexed operator)`
- `Activate(address indexed token, uint256 indexed actionId, uint256 indexed groupId, address operator)`

默认身份注册表事件：

- `SetDefaultGroupId`
- `ClearDefaultGroupId`

事件规则：

- `GroupChat.Activate` 在同笔交易内所有配置差异事件之后发出。
- `PostMessage` 必须先于 `afterPostPlugin` 调用。
- `MentionSenderId` / `MentionAll` 是链下通知索引信号，必须在 `PostMessage` 之后、`afterPostPlugin` 之前发出。
- `afterPostPlugin` 失败只发 `FailAfterPostPlugin`，不回滚消息。

## 错误

核心错误：

- `GroupNotExist`
- `ChatAlreadyActivated`
- `ChatNotActivated`
- `PostingNotAllowed`
- `NotChatOwner`
- `NotChatOwnerOrDelegateIdOwner`
- `SenderAddressNotSenderIdOwner`
- `RoundNotStarted`
- `Reentrant`
- `PhaseBlocksZero`

Rule slot 错误：

- `SourceAddressHasNoCode`
- `PluginAddressHasNoCode`
- `ScopeRejected`
- `BanRejected`
- `ScopeSourceFailed`
- `BanSourceFailed`

消息错误：

- `ContentEmpty`
- `ContentTooLong`
- `TooManyMentionedSenderIds`
- `DuplicateMentionedSenderId`
- `InvalidQuotedMessageId`
- `InvalidMessageId`

默认身份错误：

- `DefaultGroupIdNotSet`
- `GroupAdminHasNoCode`
- `GroupDefaultsHasNoCode`
- `GroupDefaultsGroupMismatch`
- `GroupDelegateHasNoCode`
- `GroupDelegateGroupMismatch`
- `MentionAllUnauthorized`
