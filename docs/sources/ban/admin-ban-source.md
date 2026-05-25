# Admin 黑名单 BanSource

- 模块：Admin 黑名单 BanSource
- 类型：`banSource`
- 定位：把 `GroupBanList` 手工黑名单适配为发言拒绝规则

## 1. 边界

- 不处理基础发言资格；基础发言资格由 `GroupChat.scopeSource` 判断。
- 不维护黑名单；黑名单由 [GroupBanList](../../group-ban-list.md) 统一维护。
- 不维护管理员名单；管理员名单由 [GroupAdmin](../../group-admin.md) 统一维护。

## 2. 黑名单管理

黑名单写接口在 `GroupBanList`：

- `GroupBanList` 读取 `GroupAdmin.adminIdOf(groupId, msg.sender)`，或 `GroupAdmin.ownerOrDelegateIdOf(groupId, msg.sender)` 命中的当前 owner / delegate；返回非 `0` 才允许。
- owner / delegate 默认可管理黑名单，不需要把自己的默认身份 NFT 加入该群管理员集合。
- NFT 转让、默认身份变化、delegate 变化都会实时影响权限。

## 3. 判定适配

`isBanned` 判定顺序固定为：

```text
GroupBanList.isBanned(groupId, senderId, senderAddress)
```

## 4. 接口

- `GROUP_BAN_LIST_ADDRESS()`
- `isBanned(uint256 groupId, uint256 senderId, address senderAddress)`
