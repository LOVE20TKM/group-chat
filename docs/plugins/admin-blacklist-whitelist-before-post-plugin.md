# Admin 黑白名单 beforePost 插件

- 模块：Admin 黑白名单 beforePost 插件
- 类型：`beforePost`
- 定位：由指定管理身份维护黑名单，由群聊所属身份维护白名单的轻量插件

## 1. 边界

- 适用于运营群、服务群、公告群等需要快速禁言或放行的场景
- 不是治理投票插件
- 不处理提案、快照、投票轮次
- 只影响未来发言，不回溯历史消息
- `senderGroupId` 是主身份主体
- 地址名单保留，作为辅助风控层

## 2. 角色

| 名称 | 含义 |
| --- | --- |
| `chatGroupId` | 群聊所属身份 NFT，也是被保护的群聊 |
| `adminGroupId` | 黑名单管理身份 NFT |
| chat controller | `chatGroupId` 当前 owner，或 `delegateGroupIdOf(chatGroupId)` 当前 owner |
| admin controller | `adminGroupId` 当前 owner，或 `delegateGroupIdOf(adminGroupId)` 当前 owner |

## 3. 核心规则

- 每个 `chatGroupId` 独立配置一个 `adminGroupId`
- `chat controller` 只能设置 `adminGroupId` 和管理白名单
- `admin controller` 只能管理黑名单
- 白名单优先级高于黑名单
- 权限必须实时读取当前 owner / `delegateGroupId` 对应 owner，不得缓存权限地址
- 不允许存在协议级全局管理员

`beforePost` 判定顺序固定为：

1. `senderGroupId` 命中白名单，直接允许
2. 否则若 `senderAddress` 命中地址黑名单，拒绝
3. 否则若 `senderGroupId` 命中身份黑名单，拒绝
4. 否则允许

说明：

- `senderGroupId` 是主身份主体
- `senderAddress` 是辅助风控主体

## 4. 状态要求

每个 `chatGroupId` 至少维护：

- `adminGroupId`
- `configVersion`
- `addressBlacklistVersion`
- `senderGroupIdBlacklistVersion`
- `senderGroupIdWhitelistVersion`
- `mapping(address => bool) addressBlacklist`
- `mapping(uint256 => bool) senderGroupIdBlacklist`
- `mapping(uint256 => bool) senderGroupIdWhitelist`

约束：

- 黑白名单必须按 `chatGroupId` 隔离
- 插件不得保存 owner 或权限地址快照
- 若 `adminGroupId` 变更，旧黑名单应逻辑失效，优先用 `epoch` / `version` 处理

## 5. 最小接口

- `setAdminGroup(uint256 chatGroupId, uint256 adminGroupId)`
- `setAddressBlacklist(uint256 chatGroupId, address[] accounts, bool listed)`
- `setSenderGroupIdBlacklist(uint256 chatGroupId, uint256[] senderGroupIds, bool listed)`
- `setSenderGroupIdWhitelist(uint256 chatGroupId, uint256[] senderGroupIds, bool listed)`
- `adminGroupOf(uint256 chatGroupId)`
- `isAddressBlacklisted(uint256 chatGroupId, address account)`
- `isSenderGroupIdBlacklisted(uint256 chatGroupId, uint256 senderGroupId)`
- `isSenderGroupIdWhitelisted(uint256 chatGroupId, uint256 senderGroupId)`
- `getAddressBlacklist(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `getSenderGroupIdBlacklist(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `getSenderGroupIdWhitelist(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `beforePost(uint256 chatGroupId, uint256 senderGroupId, address senderAddress, string content)`

说明：

- `senderGroupId` 是主要名单主体
- `senderAddress` 保留给辅助风控
- 未配置 `adminGroupId` 时，插件应视为未完成配置，不应静默放行异常状态

## 6. 事件

至少需要：

- `AdminGroupSet`
- `AddressBlacklistSet`
- `SenderGroupIdBlacklistSet`
- `SenderGroupIdWhitelistSet`

事件至少应包含：

- `chatGroupId`
- `adminGroupId`（如适用）
- `operator`
- `targetAddress` 或 `targetSenderGroupId`
- `listed`
- `version`

## 7. 典型流程

1. `chat controller` 挂载插件并设置 `adminGroupId`
2. `admin controller` 维护地址黑名单与身份黑名单
3. `chat controller` 维护身份白名单
4. 主协议在发言前调用 `beforePost`

## 8. 验收要点

- 非 `chat controller` 不能设置 `adminGroupId`
- 非 `admin controller` 不能修改黑名单
- 非 `chat controller` 不能修改白名单
- 身份白名单命中时必须覆盖黑名单
- NFT 转让或 `delegateGroupId` 变化后，旧权限必须立即失效
- 所有关键状态都可链上查询并由事件追踪
