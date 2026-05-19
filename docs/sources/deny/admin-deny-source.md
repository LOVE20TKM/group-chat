# Admin 黑名单 DenySource

- 模块：Admin 黑名单 DenySource
- 类型：`denySource`
- 定位：由共享 `GroupAdmin` 授权管理员维护黑名单

## 1. 边界

- 不处理基础发言资格；基础发言资格由 `GroupChat.scopeSource` 判断。
- 不维护管理员名单；管理员名单由 [GroupAdmin](../../group-admin.md) 统一维护。
- 黑名单支持 `senderAddress` 与 `senderId` 两个维度。
- 状态按 `groupId` 隔离。

## 2. 权限

- 黑名单写接口读取 `GroupAdmin.adminIdOf(groupId, msg.sender)`；返回非 `0` 才允许。
- owner / delegate 若要管理黑名单，也需要把自己的默认身份 NFT 加入该群管理员集合。
- NFT 转让、默认身份变化、delegate 变化都会实时影响权限。

## 3. 判定

`isDenied` 判定顺序固定为：

1. 若 `senderAddress` 命中地址黑名单，返回 `true`
2. 否则若 `senderId` 命中身份黑名单，返回 `true`
3. 否则返回 `false`

## 4. 接口

- `denyBySenderIds(uint256 groupId, uint256[] senderIds)`
- `undenyBySenderIds(uint256 groupId, uint256[] senderIds)`
- `denyBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `undenyBySenderAddresses(uint256 groupId, address[] senderAddresses)`
- `denyBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `undenyBySenders(uint256 groupId, uint256[] senderIds, address[] senderAddresses)`
- `isDenied(uint256 groupId, uint256 senderId, address senderAddress)`
- `addressDenyDetails(uint256 groupId, address[] senderAddresses)`：批量返回 `denied`、`operatorAddresses`、`operatorIds`。
- `senderIdDenyDetails(uint256 groupId, uint256[] senderIds)`：批量返回 `denied`、`operatorAddresses`、`operatorIds`。
- `addressDenyListCount` / `addressDenyList`：分页返回地址黑名单目标、同页拉黑操作者地址、同页操作者 NFT。
- `senderIdDenyListCount` / `senderIdDenyList`：分页返回 NFT 黑名单目标、同页拉黑操作者地址、同页操作者 NFT。
- `stateVersion(uint256 groupId)`

两个详情读接口用于前端消息列表分别缓存地址黑名单、NFT 黑名单状态与当前操作者信息。
最终隐藏状态由前端合成：`addressDenied || senderIdDenied`。

黑名单操作者字段用于当前状态展示，不是历史审计：

- 只有真正把目标从“未拉黑”改为“已拉黑”的调用会记录操作者。
- 目标已在黑名单中时，重复拉黑不会覆盖原操作者。
- 目标移出黑名单时，操作者记录同步清空。
- 未在当前黑名单中的目标返回 `operatorAddress=address(0), operatorId=0`。
