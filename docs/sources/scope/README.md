# ScopeSource

ScopeSource 判断“某身份 / 地址本来是否有资格发言”。

## 主协议语义

- `scopeSource = address(0)` 表示默认允许。
- 非零 `scopeSource` 必须有代码。
- `scopeSource.canPost(...) == false` 时，`post(...)` 整笔 revert。
- `scopeSource` 调用失败时，`GroupChat.canPost(...)` 返回 `ScopeSourceFailed.selector`。

## 接口

```solidity
function canPost(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external view returns (bool);
```

## 状态边界

- 主协议不存 source 的 `configData`。
- source 自己按 `groupId` 隔离状态。
- source 内部配置权限应实时锚定 chat owner / 有效 delegate。
- 主协议停止发言不影响 source 内部配置写；source 自己按权限控制。

## 当前实现

当前实现的 `ScopeSource` 包括四个 typed Manager 与 `GroupJoinScopeSource`：

- [TokenGroupChatManager](../../managers/token.md)
- [TokenGovGroupChatManager](../../managers/token-gov.md)
- [TokenActionGroupChatManager](../../managers/token-action.md)
- [TokenActionGovGroupChatManager](../../managers/token-action-gov.md)
- [GroupJoinScopeSource](./group-join-scope-source.md)

链群服务者管理型群聊不使用 Manager。其 `scopeSource` 应挂载 `GroupJoinScopeSource`，用于判断发送地址是否当前属于该链群。

专用接口位于 `src/interfaces/sources/scope/IGroupJoinScopeSource.sol`。

详见：[群聊类型](../../chat-types.md)。

## 前端规则

- 未在可信地址表中的 source，不调用专用展示接口。
- 可信 source 可选实现 `stateVersion(groupId)` 和 `StateVersionChanged`，供前端重拉专用状态。
