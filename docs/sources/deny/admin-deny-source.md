# Admin 黑名单与豁免名单 DenySource

- 模块：Admin 黑名单与豁免名单 DenySource
- 类型：`denySource`
- 定位：由共享 `GroupAdmin` 授权管理员维护黑名单，由 owner / delegate 维护豁免名单

## 1. 边界

- 不处理基础发言资格；基础发言资格由 `GroupChat.scopeSource` 判断。
- 不维护管理员名单；管理员名单由 [GroupAdmin](../../group-admin.md) 统一维护。
- 黑名单支持 `senderAddress` 与 `senderId` 两个维度。
- 豁免名单只支持 `senderId` 维度，只豁免黑名单，不增加基础发言资格。
- 状态按 `groupId` 隔离。

## 2. 权限

- 黑名单写接口读取 `GroupAdmin.adminIdOf(groupId, msg.sender)`；返回非 `0` 才允许。
- 豁免名单写接口读取 `GroupAdmin.ownerOrDelegateIdOf(groupId, msg.sender)`；返回非 `0` 才允许。
- owner / delegate 若要管理黑名单，也需要把自己的默认身份 NFT 加入该群管理员集合。
- NFT 转让、默认身份变化、delegate 变化都会实时影响权限。

## 3. 判定

`isDenied` 判定顺序固定为：

1. 若 `senderId` 命中豁免名单，返回 `false`
2. 否则若 `senderAddress` 命中地址黑名单，返回 `true`
3. 否则若 `senderId` 命中身份黑名单，返回 `true`
4. 否则返回 `false`

## 4. 接口

- `denyBySenderIds(uint256 groupId, uint256[] senderIds)`
- `undenyBySenderIds(uint256 groupId, uint256[] senderIds)`
- `denyBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `undenyBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `denyBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `undenyBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `exemptSenderIds(uint256 groupId, uint256[] senderIds)`
- `unexemptSenderIds(uint256 groupId, uint256[] senderIds)`
- `isDenied(uint256 groupId, uint256 senderId, address senderAddress)`
- `isAddressDeniedBatch(uint256 groupId, address[] senderAddresses)`
- `isSenderIdDeniedBatch(uint256 groupId, uint256[] senderIds)`
- `isSenderIdExemptBatch(uint256 groupId, uint256[] senderIds)`
- `addressDenyListCount` / `addressDenyList`
- `senderIdDenyListCount` / `senderIdDenyList`
- `senderIdExemptListCount` / `senderIdExemptList`
- `stateVersion(uint256 groupId)`

三个批量读接口用于前端消息列表分别缓存地址黑名单、NFT 黑名单、NFT 豁免状态。
最终隐藏状态由前端合成：`!senderIdExempt && (addressDenied || senderIdDenied)`。
