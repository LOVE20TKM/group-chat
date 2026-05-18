# GroupMember Scope

- 模块：成员 NFT ScopeSource
- 类型：`scopeSource`
- 定位：由管理员维护某个群聊的可发言成员 NFT 名单

## 1. 语义

`GroupMemberScope` 按 `groupId` 维护 `senderId` 成员名单：

```text
memberIds[groupId].contains(senderId)
```

含义：

- 成员资格绑定发言身份 NFT，不绑定当前钱包地址。
- NFT 转让后，成员资格随 NFT 转移。
- 主协议已保证 `senderAddress` 是 `senderId` 当前 owner。

## 2. 权限

`GroupMemberScope` 构造时固定 `GroupAdmin` 地址。

- 管理员名单由 `GroupAdmin` 维护。
- 命中 `GroupAdmin.adminIdOf(groupId, msg.sender)` 的 admin 可增删成员 NFT。
- owner / delegate 若要管理成员名单，也需要把自己的默认身份 NFT 加入该群管理员集合。

## 3. 配置

构造参数：

```solidity
constructor(address groupAdmin)
```

挂载方式：

```text
GroupChat.scopeSource = GroupMemberScope
GroupChat.denySource = AdminDenySource
```

适合纯手工成员制群聊。若希望链群行动参与者也能发言，挂载 `GroupJoinScopeSource`。

## 4. 接口

- `addMemberIds(uint256 groupId, uint256[] memberIds)`
- `removeMemberIds(uint256 groupId, uint256[] memberIds)`
- `isMemberId(uint256 groupId, uint256 memberId)`
- `isMemberIdBatch(uint256 groupId, uint256[] memberIds)`
- `memberIdsCount(uint256 groupId)`
- `memberIds(uint256 groupId, uint256 offset, uint256 limit)`
- `stateVersion(uint256 groupId)`
- `canPost(uint256 groupId, uint256 senderId, address senderAddress)`
