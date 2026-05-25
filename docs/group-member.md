# GroupMember

`GroupMember` 是群级共享成员 NFT 配置合约。它不决定发言资格，只回答某个 `senderId` 是否是某个 `groupId` 下的成员。

## 语义

- 成员资格绑定 `GroupNFT`，不是地址。
- NFT 转让后，成员资格随 NFT 转移。
- 成员名单由命中 `GroupAdmin.adminIdOf(groupId, msg.sender)` 的 admin 管理。
- owner / delegate 若要管理成员名单，也需要把自己的默认身份 NFT 加入该群管理员集合。

## 接口

- `addMemberIds(uint256 groupId, uint256[] memberIds)`
- `removeMemberIds(uint256 groupId, uint256[] memberIds)`
- `isMemberId(uint256 groupId, uint256 memberId)`
- `isMemberIdBatch(uint256 groupId, uint256[] memberIds)`
- `memberIdsCount(uint256 groupId)`
- `memberIds(uint256 groupId, uint256 offset, uint256 limit)`

`GroupMemberScope`、`GroupJoinScopeSource` 等发言规则模块应读取同一个 `GroupMember`，避免每个 scope source 维护一份割裂的成员名单。
