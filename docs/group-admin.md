# GroupAdmin

`GroupAdmin` 是群级共享管理员配置合约。它不决定发言资格，也不决定是否禁言，只回答某个地址当前是否拥有某个 `groupId` 下的管理身份。

## 语义

- 管理员列表配置的是 `GroupNFT` id，但权限生效绑定设置时的地址快照。
- `addAdmins(groupId, adminIds)` 与 `removeAdmins(groupId, adminIds)` 只能由 `GroupNFT.ownerOf(groupId)` 当前 owner 或 `GroupDelegate.ownerOrDelegateIdOf(groupId, account)` 命中的有效 delegate owner 调用。
- `addAdmins` 会按每个 `adminId` 记录调用时的 `groupId` owner，以及该 `adminId` 当时的 owner；已存在的 `adminId` 会刷新这两个快照。
- `adminIdOf` 需要账号当前默认身份命中该 `adminId`，且 `groupId` owner 与 `adminId` owner 都仍等于设置时快照。
- 群 NFT 或 admin NFT 转让后，对应 admin 权限自动失效；NFT 转回快照地址后可自动恢复。若要让新 owner 获得权限，需要 owner / delegate 重新 `addAdmins` 确认。

## 接口

- `addAdmins(uint256 groupId, uint256[] adminIds)`：增量添加或重新确认管理员 NFT
- `removeAdmins(uint256 groupId, uint256[] adminIds)`：增量移除管理员 NFT
- `adminIdOf(uint256 groupId, address account)`：命中管理员 NFT 时返回该 NFT id，否则返回 `0`
- `ownerOrDelegateIdOf(uint256 groupId, address account)`：owner 返回 `groupId`，delegate 返回 `delegateId`，否则返回 `0`
- `isAdminId(uint256 groupId, uint256 adminId)`：该管理员 NFT 在当前快照约束下仍有效时返回 `true`
- `adminIds(uint256 groupId)`：返回配置列表与同位置的当前有效性，不过滤已因转让失效的 NFT

## 事件

- `SetAdmin`：管理员 NFT 被加入或移出配置集合时发出。
- `SetAdminSnapshot`：`addAdmins` 新增或重新确认管理员 NFT，导致该 `adminId` 的群 owner / admin owner 快照变化时发出。

`GroupBanList`、`GroupMember` 等 owner-admin 管理型模块应固定读取同一个 `GroupAdmin`，避免每个模块维护一份割裂的管理员名单。
