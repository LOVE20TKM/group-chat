# GroupJoin ScopeSource

- 模块：链群参与资格 ScopeSource
- 类型：`scopeSource`
- 定位：允许成员 NFT 或链群行动参与地址发言

## 1. 语义

`GroupJoinScopeSource` 组合两种资格：

```text
GroupMember.isMemberId(groupId, senderId)
||
GroupJoin.gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) > 0
```

含义：

- `senderId` 被加入 `GroupMember` 成员 NFT 名单时，可发言。
- `senderAddress` 当前在该链群下参与至少一个代币社区行动时，也可发言。
- 手工成员资格随 NFT 转移；链群行动资格随 `GroupJoin` 地址索引实时变化。

## 2. 边界

- 不自己维护成员名单，只读取已部署的 `GroupMember`。
- 不处理黑名单；黑名单应挂 `AdminBanSource`。
- 不区分具体 token / action；链群行动资格只判断当前是否属于该链群。

## 3. 配置

构造参数：

```solidity
constructor(address groupMember, address groupJoin)
```

挂载方式：

```text
GroupChat.scopeSource = GroupJoinScopeSource
GroupChat.banSource = AdminBanSource
```

链群服务者也可以改挂 `GroupMemberScope`，得到纯手工成员制发言资格。

## 4. 接口

```solidity
function canPost(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external view returns (bool);
```

附加依赖查询：

- `GROUP_MEMBER_ADDRESS()`
- `GROUP_JOIN_ADDRESS()`
