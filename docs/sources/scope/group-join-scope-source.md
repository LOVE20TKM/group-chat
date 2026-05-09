# GroupJoin ScopeSource

- 模块：链群参与资格 ScopeSource
- 类型：`scopeSource`
- 定位：判断发送地址当前是否属于某个链群

## 1. 语义

`GroupJoinScopeSource` 不维护成员表，只读取链群扩展 `GroupJoin` 的全局 g 索引：

```text
GroupJoin.gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) > 0
```

含义：

- `groupId` 直接对应链群 `groupId`
- `senderAddress` 当前在该链群下参与至少一个代币社区行动时，可发言
- 退出最后一个相关行动后，`GroupJoin` 会移除 g 索引，发言资格随之失效

## 2. 边界

- 不检查 `senderId`；主协议已保证 `senderAddress` 是 `senderId` 当前 owner。
- 不处理黑名单；黑名单应挂 `AdminDenySource`。
- 不处理链群服务者管理权限；管理权限仍由 `GroupChat` owner / delegate 与 `AdminDenySource` 处理。
- 不区分具体 token / action；只判断当前是否属于该链群。

## 3. 配置

构造参数：

```solidity
constructor(address groupJoin)
```

挂载方式：

```text
GroupChat.scopeSource = GroupJoinScopeSource
GroupChat.denySource = AdminDenySource
```

## 4. 接口

```solidity
function canPost(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external view returns (bool);
```

`senderId` 被忽略。
