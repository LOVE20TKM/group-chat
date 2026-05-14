# Admin 黑名单与豁免名单 DenySource

- 模块：Admin 黑名单与豁免名单 DenySource
- 类型：`denySource`
- 定位：由管理员 NFT 维护黑名单，由群聊 NFT 当前 owner / 有效代理配置管理员与维护豁免名单

## 1. 边界

- 适用于中心化群聊、链群群聊等需要管理员禁言的场景
- 不处理基础发言资格；基础发言资格由 `GroupChat.scopeSource` 判断
- 不处理治理投票黑名单
- 不处理提案、快照、投票轮次
- 不处理 `mentionAll`、频率、内容格式等额外发言前规则
- 只影响未来发言，不回溯历史消息
- 黑名单同时支持 `senderAddress` 与 `senderId` 两个维度，豁免名单只支持 `senderId` 维度
- 一个 DenySource 合约可以被多个 `groupId` 复用
- 同一 DenySource 合约复用时，所有管理员、黑名单、豁免名单状态都必须按 `groupId` 隔离

## 2. 角色

| 名称 | 含义 |
| --- | --- |
| `groupId` | 群聊所属身份 NFT，也是被保护的群聊 |
| `operatorId` | 管理员路径下，默认身份注册表 `defaultGroupIdOf(msg.sender)` 返回的当前默认身份 NFT |
| `adminId` | `groupId` 作用域下管理员 NFT 集合中的一个管理员 NFT |
| owner | `GroupNFT.ownerOf(groupId)` 当前地址 |
| delegate | `GroupChat.delegateIdOf(groupId)` 对应身份 NFT 的当前 owner |
| admin | `operatorId` 命中该 `groupId` 配置的 `adminIds` 中任一项 |

## 3. 核心规则

- 所有权限设置、管理员配置、黑名单、豁免名单都必须按 `groupId` 隔离
- 不允许存在 DenySource 级全局管理员
- 每个 `groupId` 可独立配置管理员 NFT 集合，数量由 `MAX_ADMIN_IDS` 硬限制，部署默认 `20`
- owner / delegate 权限直接按 `msg.sender` 当前是否持有对应 NFT 判断
- admin 权限以 `operatorId = defaultGroupIdOf(msg.sender)` 作为权限主体
- 为保持写接口简单，当前不额外提供显式传入 `operatorId` 的双接口
- 走 admin 权限路径时，未设置默认身份 NFT，或默认身份 NFT 不具备 admin 权限时，必须拒绝
- owner / delegate 可以配置管理员、管理豁免名单
- admin 只能管理黑名单
- owner / delegate 若也要管理黑名单，必须把自己当前默认身份 NFT 加入管理员集合
- 豁免名单只豁免黑名单，不提供基础发言资格
- 权限必须实时读取默认身份注册表、`ownerOf(groupId)`、`delegateIdOf(groupId)` 与 delegate NFT 当前 owner，不得缓存权限地址或权限快照
- 管理员 NFT 集合变更不影响既有黑名单与豁免名单内容

owner / delegate 权限判定顺序：

1. 若 `msg.sender == GroupNFT.ownerOf(groupId)`，视为 owner 权限
2. 否则读取 `delegateId = GroupChat.delegateIdOf(groupId)`
3. 若 `delegateId != 0 && msg.sender == GroupNFT.ownerOf(delegateId)`，视为 delegate 权限
4. 否则拒绝

黑名单写接口只走 admin 权限路径：

1. 读取 `operatorId = GroupDefaults.defaultGroupIdOf(msg.sender)`
2. 若 `operatorId != 0 && adminIdListed[groupId][operatorId] == true`，允许修改黑名单
3. 否则拒绝

因此：

- 当前持有 `groupId` NFT 的地址，即使没有把 `groupId` 设为默认身份，也可以配置管理员和豁免名单。
- 当前 delegate NFT owner，即使没有把该 delegate NFT 设为默认身份，也可以配置管理员和豁免名单。
- 当前管理员 NFT owner，如果没有把对应管理员 NFT 设为默认身份，不能行使 DenySource admin 权限。
- 当前 owner / delegate 如果没有通过默认身份 NFT 命中管理员集合，不能修改黑名单。
- owner / delegate NFT 转让后，旧地址权限必须立即失效。
- 管理员 NFT 转让后，旧地址的 `GroupDefaults.defaultGroupIdOf(...)` 必须返回 `0`，旧地址 admin 权限必须立即失效。

`isDenied` 判定顺序固定为：

1. 若 `senderId` 命中豁免名单，返回 `false`
2. 否则若 `senderAddress` 命中地址黑名单，返回 `true`
3. 否则若 `senderId` 命中身份黑名单，返回 `true`
4. 否则返回 `false`

说明：

- 基础发言资格已由 `GroupChat.scopeSource` 在调用 `denySource` 前判断
- `senderAddress` 与 `senderId` 都可以作为黑名单目标
- 豁免绑定发言身份 NFT，不绑定当前 owner 地址
- `exemptList` 不提供基础发言资格

## 4. 状态要求

DenySource 合约全局至少维护：

- `address immutable GROUP_CHAT_ADDRESS`
- `uint256 immutable MAX_ADMIN_IDS`

每个 `groupId` 作用域至少维护：

- `mapping(uint256 => bool) adminIdListed`
- `mapping(address => bool) addressDenied`
- `mapping(uint256 => bool) senderIdDenied`
- `mapping(uint256 => bool) senderIdExempt`
- `uint256[] adminIds`
- `address[] addressDenyList`
- `uint256[] senderIdDenyList`
- `uint256[] senderIdExemptList`
- 对应 `indexPlusOne` 映射，用于去重、删除、分页
- `uint256 stateVersion`，任意批量写调用发生至少一项实际状态变化时递增一次

约束：

- 管理员集合、黑名单、豁免名单都必须按 `groupId` 隔离
- DenySource 不得保存 owner、delegate 或 admin 当前 owner 地址快照
- DenySource 部署时固定 `GROUP_CHAT_ADDRESS` 地址，后续不得修改
- `setAdmins(...)` 输入必须去重
- `setAdmins(...)` 允许传空数组，用于清空当前 `groupId` 的管理员 NFT 集合
- `setAdmins(...)` 传入的每个 `adminId` 都必须对应当前存在的 `GroupNFT`
- 可枚举集合必须去重；黑名单与豁免名单支持分页查询，管理员集合因受 `MAX_ADMIN_IDS` 限制可全量返回
- 删除可使用 `swap & pop`，分页返回顺序不作协议承诺

## 5. 最小接口

- `setAdmins(uint256 groupId, uint256[] adminIds)`
- `addDenyListsBySenderIds(uint256 groupId, uint256[] targetSenderIds)`：逐个通过 `ownerOf(targetSenderId)` 解析地址，同时加入地址与 NFT 黑名单
- `removeDenyListsBySenderIds(uint256 groupId, uint256[] targetSenderIds)`：逐个通过 `ownerOf(targetSenderId)` 解析地址，同时移除地址与 NFT 黑名单
- `addDenyListsBySenderAddresses(uint256 groupId, address[] targetAddresses)`：逐个加入地址黑名单；若地址有有效默认 NFT，同时加入 NFT 黑名单
- `removeDenyListsBySenderAddresses(uint256 groupId, address[] targetAddresses)`：逐个移除地址黑名单；若地址有有效默认 NFT，同时移除 NFT 黑名单
- `addExemptListBySenderIds(uint256 groupId, uint256[] senderIds)`
- `removeExemptListBySenderIds(uint256 groupId, uint256[] senderIds)`
- `isAdminId(uint256 groupId, uint256 adminId)`
- `isAddressDenied(uint256 groupId, address account)`
- `isSenderIdDenied(uint256 groupId, uint256 senderId)`
- `isSenderIdExempt(uint256 groupId, uint256 senderId)`
- `MAX_ADMIN_IDS()`
- `adminIds(uint256 groupId)`
- `addressDenyListCount(uint256 groupId)`
- `addressDenyList(uint256 groupId, uint256 offset, uint256 limit)`
- `senderIdDenyListCount(uint256 groupId)`
- `senderIdDenyList(uint256 groupId, uint256 offset, uint256 limit)`
- `senderIdExemptListCount(uint256 groupId)`
- `senderIdExemptList(uint256 groupId, uint256 offset, uint256 limit)`
- `isDenied(uint256 groupId, uint256 senderId, address senderAddress)`
- `isAddressDeniedBatch(uint256 groupId, address[] senderAddresses)`
- `isSenderIdDeniedBatch(uint256 groupId, uint256[] senderIds)`
- `isSenderIdExemptBatch(uint256 groupId, uint256[] senderIds)`
- `stateVersion(uint256 groupId)`

三个批量读接口用于前端消息列表分别缓存地址黑名单、NFT 黑名单、NFT 豁免状态。
最终隐藏状态由前端合成：`!senderIdExempt && (addressDenied || senderIdDenied)`。

## 6. 事件

至少需要：

- `AdminSet`
- `AddressDenySet`
- `SenderIdDenySet`
- `SenderIdExemptSet`
- `StateVersionChanged`

事件至少包含：

- `groupId`
- `operator`
- `operatorId`
- `adminId`，如适用
- `targetAddress` 或 `targetSenderId`
- `listed`
- `stateVersion`，如适用

批量写接口必须对每个实际变更目标各自 `emit` 一条明细事件；同一批实际变更的明细事件使用同一个 `stateVersion`。

每次外部名单写调用，包括 `setAdmins(...)`，若至少发生一项实际状态变化，必须只递增一次该 `groupId` 的 `stateVersion`，并只发出一条：

```solidity
event StateVersionChanged(
    uint256 indexed groupId,
    uint256 stateVersion
);
```

若输入没有带来实际状态变化，不递增 `stateVersion`，也不发出 `StateVersionChanged`。

## 7. 典型流程

1. owner 或 delegate 挂载 DenySource
2. owner 或 delegate 配置管理员 NFT 集合
3. admin 维护黑名单
4. owner / delegate 维护豁免名单
5. 主协议在发言资格通过后调用 `isDenied`

## 8. 验收要点

- 未设置默认身份 NFT 的地址不能行使 DenySource admin 权限
- 非 owner / delegate 不能调用 `setAdmins(...)`
- 非 owner / delegate 不能修改豁免名单
- 非 admin 不能修改黑名单
- owner / delegate 想修改黑名单时，必须通过默认身份 NFT 命中管理员集合
- `setAdmins([])` 必须允许
- `setAdmins(...)` 传入不存在的 `adminId` 时必须拒绝
- 黑名单、豁免名单需支持单查和分页读列表
- 命中豁免名单时只跳过黑名单，不跳过基础发言资格
- 管理员 NFT 集合变更不得影响既有黑名单或豁免名单
- NFT 转让、默认身份 NFT 变化或 `delegateId` 变化后，旧权限必须立即失效
- 所有关键状态都可链上查询并由事件追踪
