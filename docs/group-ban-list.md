# GroupBanList

`GroupBanList` 是群级共享手工黑名单配置合约。它不决定发言资格，只回答某个地址或 `senderId` 是否被某个 `groupId` 手工禁言。

## 语义

- 黑名单支持 `senderAddress` 与 `senderId` 两个目标维度。
- `isBanned(groupId, senderId, senderAddress)` 命中任一维度即返回 `true`。
- 状态按 `groupId` 隔离。
- 管理权限来自 `GroupAdmin.adminIdOf(groupId, msg.sender)`。
- owner / delegate 若要管理黑名单，也需要把自己的默认身份 NFT 加入该群管理员集合。

## 接口

- `banBySenderIds(uint256 groupId, uint256[] senderIds)`
- `unbanBySenderIds(uint256 groupId, uint256[] senderIds)`
- `banBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `unbanBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `banBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `unbanBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `isBanned(uint256 groupId, uint256 senderId, address senderAddress)`
- `isAddressBanned(uint256 groupId, address senderAddress)`
- `isSenderIdBanned(uint256 groupId, uint256 senderId)`
- `addressBanDetails(uint256 groupId, address[] senderAddresses)`
- `senderIdBanDetails(uint256 groupId, uint256[] senderIds)`
- `addressBanListCount` / `addressBanList`
- `senderIdBanListCount` / `senderIdBanList`
- `stateVersion(uint256 groupId)`

详情和分页接口会同时返回当前拉黑操作者地址与操作者 NFT id。操作者字段用于当前状态展示，不是历史审计：

- 只有真正把目标从“未拉黑”改为“已拉黑”的调用会记录操作者。
- 目标已在黑名单中时，重复拉黑不会覆盖原操作者。
- 目标移出黑名单时，操作者记录同步清空。
- 未在当前黑名单中的目标返回 `operatorAddress=address(0), operatorId=0`。

`AdminBanSource` 应读取同一个 `GroupBanList`，避免每个 ban source 维护一份割裂的手工黑名单。
