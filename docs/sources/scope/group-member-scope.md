# GroupMember Scope

- 模块：成员 NFT ScopeSource
- 类型：`scopeSource`
- 定位：把 `GroupMember` 成员 NFT 名单适配为发言资格

## 1. 语义

`GroupMemberScope` 不维护成员名单，只读取 `GroupMember`：

```text
GroupMember.isMemberId(groupId, senderId)
```

含义：

- 成员资格绑定发言身份 NFT，不绑定当前钱包地址。
- NFT 转让后，成员资格随 NFT 转移。
- 主协议已保证 `senderAddress` 是 `senderId` 当前 owner。

## 2. 成员管理

成员名单由 `GroupMember` 维护：

- 管理员名单由 `GroupAdmin` 维护。
- 命中 `GroupAdmin.adminIdOf(groupId, msg.sender)` 的 admin，或 `GroupAdmin.ownerOrDelegateIdOf(groupId, msg.sender)` 命中的当前 owner / delegate，可增删成员 NFT。
- owner / delegate 默认可管理成员名单，不需要把自己的默认身份 NFT 加入该群管理员集合。

## 3. 配置

构造参数：

```solidity
constructor(address groupMember)
```

挂载方式：

```text
GroupChat.scopeSource = GroupMemberScope
GroupChat.banSource = AdminBanSource
```

适合纯手工成员制群聊。若希望链群行动参与者也能发言，挂载 `GroupJoinScopeSource`。

## 4. 接口

- `GROUP_MEMBER_ADDRESS()`
- `canPost(uint256 groupId, uint256 senderId, address senderAddress)`
