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
- 黑名单同时支持 `senderAddress` 与 `senderGroupId` 两个维度，豁免名单只支持 `senderGroupId` 维度
- 一个 DenySource 合约可以被多个 `chatGroupId` 复用
- 同一 DenySource 合约复用时，所有管理员、黑名单、豁免名单状态都必须按 `chatGroupId` 隔离

## 2. 角色

| 名称 | 含义 |
| --- | --- |
| `chatGroupId` | 群聊所属身份 NFT，也是被保护的群聊 |
| `operatorGroupId` | 管理员路径下，默认身份注册表 `defaultGroupIdOf(msg.sender)` 返回的当前默认身份 NFT |
| `adminGroupId` | `chatGroupId` 作用域下管理员 NFT 集合中的一个管理员 NFT |
| owner | `GroupNFT.ownerOf(chatGroupId)` 当前地址 |
| delegate | `GroupChat.delegateGroupIdOf(chatGroupId)` 对应身份 NFT 的当前 owner |
| admin | `operatorGroupId` 命中该 `chatGroupId` 配置的 `adminGroupIds` 中任一项 |

## 3. 核心规则

- 所有权限设置、管理员配置、黑名单、豁免名单都必须按 `chatGroupId` 隔离
- 不允许存在 DenySource 级全局管理员
- 每个 `chatGroupId` 可独立配置管理员 NFT 集合，建议管理员数量不超过 `10`
- owner / delegate 权限直接按 `msg.sender` 当前是否持有对应 NFT 判断
- admin 权限以 `operatorGroupId = defaultGroupIdOf(msg.sender)` 作为权限主体
- 为保持写接口简单，当前不额外提供显式传入 `operatorGroupId` 的双接口
- 走 admin 权限路径时，未设置默认身份 NFT，或默认身份 NFT 不具备 admin 权限时，必须拒绝
- owner / delegate 可以配置管理员、管理豁免名单
- admin 只能管理黑名单
- owner / delegate 若也要管理黑名单，必须把自己当前默认身份 NFT 加入管理员集合
- 豁免名单只豁免黑名单，不提供基础发言资格
- 权限必须实时读取默认身份注册表、`ownerOf(chatGroupId)`、`delegateGroupIdOf(chatGroupId)` 与 delegate NFT 当前 owner，不得缓存权限地址或权限快照
- 管理员 NFT 集合变更不影响既有黑名单与豁免名单内容

owner / delegate 权限判定顺序：

1. 若 `msg.sender == GroupNFT.ownerOf(chatGroupId)`，视为 owner 权限
2. 否则读取 `delegateGroupId = GroupChat.delegateGroupIdOf(chatGroupId)`
3. 若 `delegateGroupId != 0 && msg.sender == GroupNFT.ownerOf(delegateGroupId)`，视为 delegate 权限
4. 否则拒绝

黑名单写接口只走 admin 权限路径：

1. 读取 `operatorGroupId = GroupDefaults.defaultGroupIdOf(msg.sender)`
2. 若 `operatorGroupId != 0 && adminGroupListed[chatGroupId][operatorGroupId] == true`，允许修改黑名单
3. 否则拒绝

因此：

- 当前持有 `chatGroupId` NFT 的地址，即使没有把 `chatGroupId` 设为默认身份，也可以配置管理员和豁免名单。
- 当前 delegate NFT owner，即使没有把该 delegate NFT 设为默认身份，也可以配置管理员和豁免名单。
- 当前管理员 NFT owner，如果没有把对应管理员 NFT 设为默认身份，不能行使 DenySource admin 权限。
- 当前 owner / delegate 如果没有通过默认身份 NFT 命中管理员集合，不能修改黑名单。
- owner / delegate NFT 转让后，旧地址权限必须立即失效。
- 管理员 NFT 转让后，旧地址的 `GroupDefaults.defaultGroupIdOf(...)` 必须返回 `0`，旧地址 admin 权限必须立即失效。

`isDenied` 判定顺序固定为：

1. 若 `senderGroupId` 命中豁免名单，返回 `false`
2. 否则若 `senderAddress` 命中地址黑名单，返回 `true`
3. 否则若 `senderGroupId` 命中身份黑名单，返回 `true`
4. 否则返回 `false`

说明：

- 基础发言资格已由 `GroupChat.scopeSource` 在调用 `denySource` 前判断
- `senderAddress` 与 `senderGroupId` 都可以作为黑名单目标
- 豁免绑定发言身份 NFT，不绑定当前 owner 地址
- `exemptList` 不提供基础发言资格

## 4. 状态要求

DenySource 合约全局至少维护：

- `address immutable GROUP_CHAT`

每个 `chatGroupId` 作用域至少维护：

- `mapping(uint256 => bool) adminGroupListed`
- `mapping(address => bool) addressDenied`
- `mapping(uint256 => bool) senderGroupIdDenied`
- `mapping(uint256 => bool) senderGroupIdExempt`
- `uint256[] adminGroupIds`
- `address[] addressDenyList`
- `uint256[] senderGroupIdDenyList`
- `uint256[] senderGroupIdExemptList`
- 对应 `indexPlusOne` 映射，用于去重、删除、分页
- `uint256 stateVersion`，任意批量写调用发生至少一项实际状态变化时递增一次

约束：

- 管理员集合、黑名单、豁免名单都必须按 `chatGroupId` 隔离
- DenySource 不得保存 owner、delegate 或 admin 当前 owner 地址快照
- DenySource 部署时固定 `GROUP_CHAT` 地址，后续不得修改
- `setAdmins(...)` 输入必须去重
- `setAdmins(...)` 允许传空数组，用于清空当前 `chatGroupId` 的管理员 NFT 集合
- `setAdmins(...)` 传入的每个 `adminGroupId` 都必须对应当前存在的 `GroupNFT`
- 可枚举集合必须去重，且支持分页查询
- 删除可使用 `swap & pop`，分页返回顺序不作协议承诺

## 5. 最小接口

- `setAdmins(uint256 chatGroupId, uint256[] adminGroupIds)`
- `addDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] targetSenderGroupIds)`：逐个通过 `ownerOf(targetSenderGroupId)` 解析地址，同时加入地址与 NFT 黑名单
- `removeDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] targetSenderGroupIds)`：逐个通过 `ownerOf(targetSenderGroupId)` 解析地址，同时移除地址与 NFT 黑名单
- `addDenyListsBySenderAddresses(uint256 chatGroupId, address[] targetAddresses)`：逐个加入地址黑名单；若地址有有效默认 NFT，同时加入 NFT 黑名单
- `removeDenyListsBySenderAddresses(uint256 chatGroupId, address[] targetAddresses)`：逐个移除地址黑名单；若地址有有效默认 NFT，同时移除 NFT 黑名单
- `addExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] senderGroupIds)`
- `removeExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] senderGroupIds)`
- `isAdminGroup(uint256 chatGroupId, uint256 adminGroupId)`
- `isAddressDenied(uint256 chatGroupId, address account)`
- `isSenderGroupIdDenied(uint256 chatGroupId, uint256 senderGroupId)`
- `isSenderGroupIdExempt(uint256 chatGroupId, uint256 senderGroupId)`
- `adminGroupsCount(uint256 chatGroupId)`
- `adminGroups(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `addressDenyListCount(uint256 chatGroupId)`
- `addressDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `senderGroupIdDenyListCount(uint256 chatGroupId)`
- `senderGroupIdDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `senderGroupIdExemptListCount(uint256 chatGroupId)`
- `senderGroupIdExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `isDenied(uint256 chatGroupId, uint256 senderGroupId, address senderAddress)`
- `stateVersion(uint256 chatGroupId)`

## 6. 事件

至少需要：

- `AdminSet`
- `AddressDenySet`
- `SenderGroupIdDenySet`
- `SenderGroupIdExemptSet`
- `StateVersionChanged`

事件至少包含：

- `chatGroupId`
- `operator`
- `operatorGroupId`
- `adminGroupId`，如适用
- `targetAddress` 或 `targetSenderGroupId`
- `listed`
- `stateVersion`，如适用

批量写接口必须对每个实际变更目标各自 `emit` 一条明细事件；同一批实际变更的明细事件使用同一个 `stateVersion`。

每次外部名单写调用，包括 `setAdmins(...)`，若至少发生一项实际状态变化，必须只递增一次该 `chatGroupId` 的 `stateVersion`，并只发出一条：

```solidity
event StateVersionChanged(
    uint256 indexed chatGroupId,
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
- `setAdmins(...)` 传入不存在的 `adminGroupId` 时必须拒绝
- 黑名单、豁免名单需支持单查和分页读列表
- 命中豁免名单时只跳过黑名单，不跳过基础发言资格
- 管理员 NFT 集合变更不得影响既有黑名单或豁免名单
- NFT 转让、默认身份 NFT 变化或 `delegateGroupId` 变化后，旧权限必须立即失效
- 所有关键状态都可链上查询并由事件追踪
