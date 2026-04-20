# 链群群聊插件需求文档

- 项目：链群群聊插件
- 状态：草案
- 类型：`beforePost`
- 目标：让指定管理群负责黑名单，目标链群 `GroupNFT` 持有者或代理者负责白名单，形成链上可审计的双层发言控制。

## 1. 背景

`Group Chat` 核心协议已经支持 `beforePost` 插件，可在消息写入前做权限判断。

部分群聊场景需要：

- 由一个指定管理群统一维护禁言对象
- 由目标群自己保留本地放行能力
- 权限始终跟随 `GroupNFT` 当前持有者与代理，而不是固定管理员地址

相对治理投票型插件，这类需求更轻，决策链更短，适合运营群、服务群、公告群等需要快速处理异常账号的场景。

## 2. 目标

### 2.1 必须达到

- 每个目标群可指定一个管理群
- 管理群当前 `owner` 或 `delegate` 可管理目标群黑名单
- 目标群当前 `owner` 或 `delegate` 可管理目标群白名单
- 白名单优先级高于黑名单
- 所有权限变化都随 NFT 持有关系实时变化
- 插件判断结果可链上验证、可事件追踪

### 2.2 不追求

- 协议级全局管理员
- 消息内容审核或文本分类
- 已上链消息删除、撤回、编辑
- 复杂投票流程
- 链下审批中心

## 3. 术语

| 术语             | 含义                                                         |
| ---------------- | ------------------------------------------------------------ |
| chatGroupId      | 被本插件保护的目标群 `groupId`，等于主协议里的 `chatGroupId` |
| managerGroupId   | 被目标群指定、负责黑名单维护的管理群 `groupId`               |
| chat owner       | `ownerOf(chatGroupId)`                                       |
| chat delegate    | 目标群当前代理                                               |
| manager owner    | `ownerOf(managerGroupId)`                                    |
| manager delegate | 管理群当前代理                                               |
| blacklist        | 对目标群生效的拒绝发言地址集合                               |
| whitelist        | 对目标群生效的放行地址集合                                   |

## 4. 核心规则

### 4.1 职责分离

- 管理群负责黑名单
- 目标群负责白名单
- 黑白名单写权限必须分离
- 目标群无权直接改黑名单
- 管理群无权直接改白名单

### 4.2 优先级

`beforePost` 判断顺序必须固定为：

1. 若发送者在白名单，直接允许
2. 否则若发送者在黑名单，拒绝发送
3. 否则默认允许

这意味着白名单是对黑名单的本地覆盖。

### 4.3 动态权限

- 所有管理权限都不存地址快照
- 权限始终实时读取 `ownerOf(groupId)` 与当前 `delegate`
- 目标群 NFT 转让后，旧 `owner` / `delegate` 立即失去白名单管理权
- 管理群 NFT 转让后，旧 `owner` / `delegate` 立即失去黑名单管理权

### 4.4 组身份优先于个人身份

- 黑名单权力属于 `managerGroupId` 这个群身份，不属于某个固定地址
- 白名单权力属于 `chatGroupId` 这个群身份，不属于某个固定地址
- 只要 NFT 控制权变化，对应管理权就必须同步变化

## 5. 对象模型

每个 `chatGroupId` 至少维护：

- `managerGroupId`
- `configVersion`
- `blacklistVersion`
- `whitelistVersion`
- `mapping(address => bool) blacklist`
- `mapping(address => bool) whitelist`

设计要求：

- 黑名单、白名单都按 `chatGroupId` 隔离
- 不允许一个地址的状态污染其他群
- 插件不保存 owner / delegate 快照

## 6. 功能需求

### 6.1 配置管理群

- 目标群 `owner` 或 `delegate` 可为 `chatGroupId` 设置 `managerGroupId`
- `managerGroupId` 必须是有效的 `GroupNFT groupId`
- 未配置 `managerGroupId` 时，不应允许该插件进入可用状态
- 变更 `managerGroupId` 后，旧管理群应立即失去黑名单写权限

建议语义：

- `managerGroupId` 可等于 `chatGroupId`
- 若 `managerGroupId` 变更，旧黑名单状态应逻辑失效，避免旧管理群遗留决策延续到新管理群
- 逻辑失效应优先通过版本号或 epoch 处理，而不是依赖高成本逐项清空

验收条件：

- 非目标群 `owner` / `delegate` 不能修改 `managerGroupId`
- 更新 `managerGroupId` 后，旧管理群再写黑名单必须失败

### 6.2 黑名单管理

- 管理群 `owner` 或 `delegate` 可为目标群添加、移除黑名单地址
- 黑名单必须支持批量写入
- 黑名单必须支持单地址查询
- 黑名单变更只影响未来发言，不回溯历史消息

黑名单管理范围：

- 添加黑名单
- 移除黑名单
- 分页读取黑名单
- 查询某地址是否在黑名单

验收条件：

- 目标群 `owner` / `delegate` 不能直接修改黑名单
- 非管理群授权地址修改黑名单必须失败

### 6.3 白名单管理

- 目标群 `owner` 或 `delegate` 可添加、移除白名单地址
- 白名单必须支持批量写入
- 白名单必须支持单地址查询
- 白名单变更只影响未来发言，不回溯历史消息

白名单语义：

- 白名单是目标群的本地放行权
- 白名单优先于黑名单
- 即使地址同时命中黑名单与白名单，也必须允许发言

验收条件：

- 管理群 `owner` / `delegate` 不能直接修改白名单
- 非目标群授权地址修改白名单必须失败

### 6.4 `beforePost` 判定

插件在 `beforePost(chatGroupId, senderGroupId, senderAddress, content)` 中至少要完成：

- 检查插件配置是否完整
- 检查 `senderAddress` 是否命中白名单
- 检查 `senderAddress` 是否命中黑名单
- 返回明确 allow / reject 结果

补充语义：

- 插件内 `msg.sender` 是群聊主协议合约，不是真实发言地址
- 地址类白名单 / 黑名单判断必须使用 `senderAddress`

建议错误语义：

- 白名单命中：直接通过，不再继续检查黑名单
- 白名单未命中且黑名单命中：拒绝，并返回明确自定义错误
- 两者都未命中：通过

验收条件：

- 黑名单地址不能发言
- 白名单地址即使在黑名单中也能发言
- 不在黑白名单中的地址默认可发言

### 6.5 NFT 转让与代理语义

- 目标群代理变化后，白名单管理权立即切换
- 管理群代理变化后，黑名单管理权立即切换
- 目标群 NFT 转移后，新 `owner` 自动继承白名单管理权
- 管理群 NFT 转移后，新 `owner` 自动继承黑名单管理权
- 若主协议因 NFT 转回同一 owner 而恢复有效 `delegate`，插件管理权限也必须同步恢复

建议实现：

- 权限校验统一走“当前 owner 或主协议当前有效 `delegate`”
- 当前有效 `delegate` 必须以主协议 `delegateOf(groupId)` 为准
- 插件不得自行缓存旧 delegate

验收条件：

- 旧 `owner` / `delegate` 在转让后继续写名单必须失败
- 新 `owner` / `delegate` 无需重新注册即可立即管理对应名单

### 6.6 查询能力

插件至少需要提供：

- 读取 `managerGroupId`
- 查询地址黑名单状态
- 查询地址白名单状态
- 分页读取黑名单
- 分页读取白名单
- 读取配置版本 / 名单版本

验收条件：

- 客户端无需依赖中心化数据库也能验证某地址当前状态
- 客户端可根据事件与版本号增量同步

## 7. 推荐接口

以下接口为建议，不要求 ABI 完全一致，但实现应覆盖等价能力：

- `setManagerGroup(uint256 chatGroupId, uint256 managerGroupId)`
- `setBlacklist(uint256 chatGroupId, address[] accounts, bool listed)`
- `setWhitelist(uint256 chatGroupId, address[] accounts, bool listed)`
- `managerGroupOf(uint256 chatGroupId)`
- `isBlacklisted(uint256 chatGroupId, address account)`
- `isWhitelisted(uint256 chatGroupId, address account)`
- `getBlacklist(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `getWhitelist(uint256 chatGroupId, uint256 offset, uint256 limit)`
- `beforePost(uint256 chatGroupId, uint256 senderGroupId, address senderAddress, string content)`

命名说明：

- 这里的 `listed` 表示该地址是否存在于对应名单中
- 若实现方更偏好 `status`、`enabled` 等命名，也可以，但语义必须清晰稳定

## 8. 事件要求

至少应有以下事件：

- `ManagerGroupSet`
- `BlacklistSet`
- `WhitelistSet`

事件字段至少包含：

- `chatGroupId`
- `managerGroupId`（如适用）
- `operator`
- `account`
- `listed`
- `version`

要求：

- 批量写入时可逐条发事件，也可发批量事件
- 事件必须足够让索引器还原当前状态

## 9. 安全与实现约束

### 9.1 权限安全

- 不能存在协议级后门管理员
- 黑名单接口只能接受管理群授权
- 白名单接口只能接受目标群授权
- 权限判断必须基于实时 owner / delegate

### 9.2 状态安全

- 变更 `managerGroupId` 时必须处理旧黑名单残留问题
- 插件配置不完整时，不得静默放过本应拒绝的异常状态
- 批量操作需要有长度上限，避免超大输入

### 9.3 可审计性

- 关键状态变化必须有事件
- 名单与配置必须可链上读取
- 拒绝原因应尽量明确，便于前端提示与排查

## 10. 典型流程

### 10.1 初始化

1. 目标群 `owner` 或 `delegate` 挂载本插件
2. 目标群 `owner` 或 `delegate` 设置 `managerGroupId`
3. 插件进入可用状态

### 10.2 管理群拉黑

1. 管理群 `owner` 或 `delegate` 调用黑名单接口
2. 目标地址被加入目标群黑名单
3. 该地址后续向目标群发言时被 `beforePost` 拒绝

### 10.3 目标群放白

1. 目标群 `owner` 或 `delegate` 调用白名单接口
2. 指定地址进入目标群白名单
3. 即使该地址也在黑名单中，后续发言仍应允许

## 11. 验收清单

- 可为每个目标群独立指定管理群
- 管理群只能管黑名单，不能管白名单
- 目标群只能管白名单，不能管黑名单
- 白名单优先级高于黑名单
- 黑白名单都支持批量写入与分页读取
- NFT 转让后旧权限立即失效
- delegate 变化后旧代理立即失效
- 所有关键变更都有事件
- 插件判断无需依赖链下中心化服务
