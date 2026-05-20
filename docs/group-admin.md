# GroupAdmin

`GroupAdmin` 是群级共享管理员配置合约。它不决定发言资格，也不决定是否禁言，只回答某个地址当前是否拥有某个 `groupId` 下的管理身份。

## 语义

- 管理员绑定 `GroupNFT`，不是地址。
- `setAdmins(groupId, adminIds)` 只能由 `GroupNFT.ownerOf(groupId)` 当前 owner 或 `GroupChat.delegateIdOf(groupId)` 的有效 owner 调用。
- admin 权限通过 `GroupDefaults.defaultGroupIdOf(account)` 实时生效。
- NFT 转让、默认身份变化、delegate 变化都会实时影响权限。

## 接口

- `setAdmins(uint256 groupId, uint256[] adminIds)`
- `adminIdOf(uint256 groupId, address account)`：命中管理员 NFT 时返回该 NFT id，否则返回 `0`
- `ownerOrDelegateIdOf(uint256 groupId, address account)`：owner 返回 `groupId`，delegate 返回 `delegateId`，否则返回 `0`
- `isAdminId(uint256 groupId, uint256 adminId)`
- `adminIds(uint256 groupId)`
- `stateVersion(uint256 groupId)`

`AdminDenySource`、`GroupMember` 等 owner-admin 管理型模块应固定读取同一个 `GroupAdmin`，避免每个模块维护一份割裂的管理员名单。
