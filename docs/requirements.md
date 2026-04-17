# Group Chat 需求文档

- 项目：LOVE20 Group Chat
- 状态：草案
- 目标：基于 `GroupNFT` 的完全链上公开群聊协议
- 版本：v0.1

## 1. 背景

LOVE20 现有协议里，`GroupNFT` 已可作为链上身份与所有权凭证。群聊协议应直接复用这层身份，不再引入中心化账号系统，也不做成员表、私聊门禁或链下托管。

本协议核心判断：

- 链上公开消息天然可读
- 群聊不需要“谁能看”
- 群聊只需要“谁能发”和“谁能管”
- NFT 转让应等价于群聊控制权转让

## 2. 目标

### 2.1 必须达到

- 完全去中心化
- 部署后不可升级、不可篡改
- 无任何个体拥有特殊管理员权限
- 所有消息内容上链
- 基于 `GroupNFT` 做身份与控制权
- 支持代理管理
- 支持元信息扩展
- 支持插件扩展
- 支持按轮次分页查询消息

### 2.2 不追求

- 私聊
- 阅读权限控制
- 成员列表
- 加入 / 退出流程
- 复杂治理投票
- 链下消息存储
- 消息删除 / 编辑

## 3. 核心原则

### 3.1 身份即控制

每个 `GroupNFT` 对应一个群聊主体。`owner` 是动态概念，始终等于当前 `ownerOf(groupId)`。

### 3.2 公开即默认

消息对所有人公开可读，不做读权限隔离，也不引入“群成员”概念。

### 3.3 简单优先

协议只保留必要状态，不在协议层做复杂权限树、成员系统、子频道树或治理流程。

### 3.4 扩展外置

扩展能力通过 `meta` 与 `plugin` 完成，不污染协议最小模型。

### 3.5 写入不可逆

消息只增不改。`meta` 可更新或删除，但历史变化必须能通过事件追踪。

## 4. 术语

| 术语 | 含义 |
| --- | --- |
| GroupNFT | LOVE20 链群 NFT，作为链上身份凭证 |
| Chat | 与某个 `GroupNFT` 绑定的公开群聊 |
| groupId | 群聊唯一标识，直接使用 `GroupNFT` 编号 |
| chatGroupId | 消息目标群聊标识，等于目标 chat 的 `groupId` |
| senderGroupId | 发消息时使用的身份 `GroupNFT` 编号，可与 `chatGroupId` 相同或不同 |
| senderAddress | 实际发起交易地址，必须是 `senderGroupId` 当前 owner |
| owner | 当前持有该 `GroupNFT` 的地址，实时变化 |
| delegate | 由 owner 设置、仅可代行群管理的地址，不可代替 owner 发言 |
| meta | 群聊 KV 元信息，`key=string`，`value=bytes` |
| plugin | 消息前后钩子合约 |
| round | 群聊消息轮次，按与 core `Phase` 一致公式计算 |
| RoundSpan | 某轮次在全局消息数组中的区间，语义固定为 `[startIndex, endIndex)` |

## 5. 协议范围

### 5.1 核心范围

- 激活群聊
- 取消激活群聊
- 查询群聊
- 设置 / 更新 / 删除元信息
- 设置 / 清空代理
- 设置 / 清空插件
- 发消息
- 查询消息
- NFT 转移后控制权自然转移

### 5.2 扩展范围

- 代币社群群聊
- 治理者社群群聊
- 规则型发言控制
- 外部协议引用

### 5.3 协议不负责

- 子频道层级树
- 成员资格系统
- 群内私密消息
- 链下社交组件
- 复杂投票审批

## 6. 对象模型

### 6.1 Chat

每个 chat 至少包含：

- `groupId`，直接等于 `GroupNFT` 编号
- `owner`，实时读取当前 `ownerOf(groupId)`，不单独存储
- `active`
- `configVersion`，当前 live 配置版本号
- `firstActivatedOwner`
- `firstActivatedBlockNumber`
- `firstActivatedTimestamp`

说明：

- `firstActivatedOwner / BlockNumber / Timestamp` 仅在首次 `activateChat` 时写入
- 后续 `deactivateChat`、重新 `activateChat` 都不得改写这 3 个字段
- 尚未激活时，`firstActivated*` 为零值
- `configVersion` 只覆盖 chat 合约内 live 配置
- `configVersion` 覆盖范围包括：`active`、`meta`、`delegate`、`beforePostPlugin`、`afterPostPlugin`
- `configVersion` 不覆盖：实时 `owner`、消息、`firstActivated*`
- 前端可通过比较缓存值与 `chatInfo(groupId)` 返回的 `configVersion` 判断是否需要全量刷新配置缓存
- `chatInfo(groupId)` 必须返回与本节 `Chat` 定义一致的结构体或等价 tuple，字段顺序按本节顺序固定

### 6.2 Message

每条消息至少包含：

- `chatGroupId`
- `senderGroupId`
- `senderAddress`
- `round`
- `messageIndex`，目标群内全局消息序号，从 `0` 开始
- `content`
- `blockNumber`
- `timestamp`

实际存储模型：

- 每个 `chatGroupId` 下只有一条追加式消息列表
- `messageIndex` 以整个目标群消息列表为准，不按 `round` 重置
- `round` 只标记这条全局列表里哪一段属于该轮
- `messages(...)` 与 `messagesByRound(...)` 必须返回与本节 `Message` 定义一致的结构体数组或等价 tuple 数组，字段顺序按本节顺序固定

### 6.3 RoundSpan

每个轮次至少包含：

- `round`
- `startIndex`
- `endIndex`
- `messageCount`

说明：

- 语义固定为 `[startIndex, endIndex)`
- `startIndex`、`endIndex` 为全局消息索引边界
- 仅记录“有消息的 round”
- `rounds(...)` 与 `roundInfo(...)` 必须返回与本节 `RoundSpan` 定义一致的结构体或等价 tuple，字段顺序按本节顺序固定

### 6.4 MetaEntry

每个元信息条目至少包含：

- `key`
- `value`

说明：

- 协议链上仅保留当前值
- 历史依赖 `MetaSet` 事件追踪
- `value.length == 0` 表示删除
- `metaEntries(...)` 必须返回与本节 `MetaEntry` 定义一致的结构体数组或等价 tuple 数组，字段顺序按本节顺序固定

### 6.5 Delegate

每个 chat 至少包含一组代理状态：

- `delegate`
- `delegateOwnerSnapshot`

说明：

- `delegate` 仅在 `delegateOwnerSnapshot == ownerOf(groupId)` 时有效
- NFT 转给别人后，旧 delegate 对新 owner 立即失效
- NFT 转回同一 owner 后，旧 delegate 自动恢复

### 6.6 Plugin Slots

每个 chat 至少包含两个独立槽位：

- `beforePostPlugin`
- `afterPostPlugin`

说明：

- 每个槽位同一时间只允许一个插件
- `address(0)` 表示未挂载 / 卸载
- 插件自身状态由插件自己存储，主协议不存 `configData`

## 7. 功能需求

### 7.1 1 NFT = 1 Chat

- 每个 `GroupNFT` 只对应一个主群聊
- 群聊身份由 NFT 持有关系决定
- 群聊不再需要独立成员体系
- `owner` 必须始终实时读取 `ownerOf(groupId)`

验收条件：

- 同一个 `groupId` 只能对应一个主群聊状态空间
- NFT 转移后，新 owner 立即获得群聊控制权

### 7.2 群聊激活与关闭

- 仅当前 `owner` 可执行 `activateChat(groupId, ...)`
- 仅当前 `owner` 可执行 `deactivateChat(groupId)`
- `active = true` 时再次调用 `activateChat` 必须 `revert`
- `active = false` 时再次调用 `deactivateChat` 必须 `revert`
- 首次激活时，必须写入 `firstActivatedOwner = ownerOf(groupId)`
- 首次激活时，必须写入 `firstActivatedBlockNumber = block.number`
- 首次激活时，必须写入 `firstActivatedTimestamp = block.timestamp`
- 再次关闭 / 重新激活，不得改写 `firstActivated*`
- `active = false` 时，唯一允许的管理写操作是 `activateChat`
- `active = false` 时，禁止 `setMeta`
- `active = false` 时，禁止 `setMetaBatch`
- `active = false` 时，禁止 `setDelegate`
- `active = false` 时，禁止 `setBeforePostPlugin`
- `active = false` 时，禁止 `setAfterPostPlugin`
- `deactivateChat` 不得清空当前 `meta`、`delegate`、`beforePostPlugin`、`afterPostPlugin`
- 群聊处于关闭态时，相关只读接口仍必须返回当前存储配置
- 关闭状态不影响历史消息读取
- 恢复后继续使用同一 `groupId` 与同一历史消息

接口：

- `activateChat(groupId, metaKeys, metaValues, beforePostPlugin, afterPostPlugin, delegate_)`
- `deactivateChat(groupId)`
- `chatInfo(groupId)`

说明：

- `chatInfo(groupId)` 对存在的 `GroupNFT` 必须返回结构体
- 若对应 `GroupNFT` 不存在，才允许 `revert`
- 尚未激活时，`chatInfo(groupId)` 应返回：
- `active = false`
- `configVersion = 0`
- `firstActivatedOwner = address(0)`
- `firstActivatedBlockNumber = 0`
- `firstActivatedTimestamp = 0`
- 首次 `activateChat` 成功时，`configVersion` 必须从 `0` 变为 `1`
- 重新 `activateChat` 时，视为对当前运行配置做一次原子覆盖
- 重新 `activateChat` 时，必须先完成配置覆盖，再把 `active` 置为 `true`
- 重新 `activateChat` 时，`meta` 必须按本次入参全量覆盖当前 live 配置
- 若 `metaKeys / metaValues` 为空，则重开后当前 live `meta` 为空
- 任意成功改变 live 配置的交易，都必须让 `configVersion` 递增 1 次
- `activateChat`、`deactivateChat`、`setMeta`、`setMetaBatch`、`setDelegate`、`setBeforePostPlugin`、`setAfterPostPlugin` 都属于 live 配置变更
- 同一笔交易里即使同时改多个配置项，`configVersion` 也只递增 1 次
- `metaValue` 与 `metaEntries` 始终只返回当前 live `meta`
- 历史 `meta` 变化仍通过事件追踪，不要求链上保留旧版本可读快照
- 重新 `activateChat` 时，`beforePostPlugin` / `afterPostPlugin` / `delegate_` 都按本次入参直接覆盖
- `beforePostPlugin = address(0)` 表示清空
- `afterPostPlugin = address(0)` 表示清空
- `delegate_ = address(0)` 表示清空

验收条件：

- 未持有 NFT 的地址不能激活或关闭
- `delegate` 不能激活或关闭
- 非法状态切换必须 `revert`
- 关闭不会清空任何历史

### 7.3 主键

- `groupId` 直接等于 `GroupNFT` 的 `tokenId`
- `chat`、`meta`、`delegate`、插件状态都挂在 `groupId` 下
- 消息与轮次分页按 `chatGroupId` 归属
- `chatGroupId` 恒等于目标 chat 的 `groupId`
- `senderGroupId` 只表示发言身份，不作为 chat 主键
- 不额外引入 `chatId`、`identifier` 等同义字段

### 7.4 元信息 KV

- 每个群聊必须支持 KV 元信息
- `meta.key` 类型固定为 `string`
- `meta.value` 类型固定为 `bytes`
- 空 `key` 不允许；`bytes(key).length == 0` 时必须 `revert`
- 必须支持单键读取
- 必须支持分页枚举
- 链上只保留当前值
- 历史变化必须可通过事件追踪
- `value.length == 0` 表示删除该 key
- 对当前不存在的 `key`，`metaValue(groupId, key)` 返回空 `bytes`，不 `revert`
- 删除后 `metaValue(groupId, key)` 返回空 `bytes`
- 删除后 `metaEntries(groupId, offset, limit, reverse)` 不再包含该 key
- `metaEntries(groupId, offset, limit, reverse)` 的默认顺序必须基于当前 live key 列表的插入顺序
- `metaEntries(..., reverse = false)` 必须按该插入顺序从旧到新返回
- `metaEntries(..., reverse = true)` 必须按该插入顺序从新到旧返回
- `metaEntries(...)` 中 `offset` 必须以所选方向下的当前 live 列表顺序为基准
- `metaEntries(...)` 中 `limit == 0` 时必须返回空数组，不 `revert`
- `metaEntries(...)` 分页越界时必须返回空数组，不 `revert`
- 对已有 key 的更新不得改变其在 `metaEntries(...)` 中的位置
- 删除 key 会将其从当前 live 列表中移除
- 删除后再重新写入同名 key 时，该 key 必须作为新条目追加到当前 live 列表尾部
- 协议不预置 `link.token.*`、`link.action.*` 等推荐 key
- 协议不理解 `meta` 业务语义
- 若 `setMeta` 的新 `value` 与该 `key` 当前 live 值相同，必须 `revert`
- 若删除一个当前不存在的 `key`，必须 `revert`
- 任意成功改变 live `meta` 的交易，都必须让 `configVersion` 递增 1 次
- `setMetaBatch` 无论本次改多少个 key，`configVersion` 都只递增 1 次
- 同一笔交易里发出的多条 `MetaSet` 事件，必须携带同一个新 `configVersion`
- 前端发现 `configVersion` 变化后，应直接全量重拉当前 `metaEntries(...)`

接口：

- `setMeta(groupId, key, value)`
- `setMetaBatch(groupId, keys, values)`
- `metaValue(groupId, key)`
- `metaEntries(groupId, offset, limit, reverse)`

验收条件：

- `owner` 与有效 `delegate` 可写 `meta`
- 应支持通过 `meta` 挂任意外部引用
- 删除语义明确且可观测

### 7.5 群聊状态

- 群聊仅区分两种运行态：
- `active = true`
- `active = false`
- 协议不引入额外“已关闭但曾激活过”的独立枚举状态
- “曾被首次激活过”通过 `firstActivated*` 判断，不通过额外状态枚举判断
- `active = false` 时禁止发消息
- `active = false` 时禁止除 `activateChat` 外的管理写操作

验收条件：

- 前端仅通过 `active` 即可判断当前是否可发言 / 可管理
- 若需要判断“是否曾激活过”，可直接读取 `firstActivatedBlockNumber != 0`

### 7.6 代理机制

- 当前 `owner` 可设置 `delegate`
- `delegate` 仅可代行群管理，不可代替 owner 发言
- `delegate` 可执行：
- `setMeta`
- `setMetaBatch`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- 插件内部配置写操作
- `delegate` 不可执行：
- `activateChat`
- `deactivateChat`
- 使用任意 `senderGroupId` 发言
- `delegate == owner` 不允许；设置为 owner 自己时必须 `revert`
- 将 `delegate` 重复设置为当前存储中的相同配置值时，必须 `revert`
- 代理状态必须可查询
- 代理配置必须可清空
- `setDelegate(groupId, address(0))` 表示清空当前存储的 `delegate` 配置
- `deactivateChat` 不清空 `delegate`
- `delegate` 有效条件必须绑定当前 `owner`

接口：

- `setDelegate(groupId, delegate)`
- `delegateOf(groupId)`

说明：

- `delegateOf(groupId)` 必须返回当前有效的 `delegate`
- 若当前存储的 `delegateOwnerSnapshot != ownerOf(groupId)`，则 `delegateOf(groupId)` 必须返回 `address(0)`
- 当 NFT 转回与 `delegateOwnerSnapshot` 相同的 owner 时，`delegateOf(groupId)` 必须再次返回原先配置的 `delegate`

验收条件：

- NFT 转移后，旧 delegate 对新 owner 立即失效
- NFT 转回同一 owner 后，旧 delegate 自动恢复
- `delegate` 不能绕过 `active` 状态
- `delegate` 不能代替 owner 作为 `senderGroupId` 发消息

### 7.7 发消息

- 发消息时必须同时指定 `chatGroupId` 与 `senderGroupId`
- `senderGroupId` 表示发言身份，可与 `chatGroupId` 相同或不同
- `senderAddress` 为实际调用地址
- `msg.sender` 必须是 `senderGroupId` 当前 owner
- `delegate` 不得代替 owner 作为 `senderGroupId` 发消息
- `chatGroupId` 对应 chat 必须处于 `active`
- `senderGroupId` 必须对应一个当前存在的 `GroupNFT`
- 不要求 `senderGroupId` 自己的 chat 已激活
- 是否允许 `senderGroupId` 向 `chatGroupId` 发消息，由该 chat 的插件或外部规则决定
- 若未配置 `beforePost` 插件，则在通过 owner、`active`、内容长度等核心校验后默认允许发送
- 协议默认规则不得要求 `senderGroupId == chatGroupId`
- 消息内容必须完整上链
- 单次 `post` 只发 1 条消息，不做批量消息接口
- 消息只能新增，不能编辑或删除
- 空消息不允许发送；`bytes(content).length == 0` 时必须 `revert`
- 单条消息内容长度上限固定为 `16384` bytes
- `bytes(content).length > 16384` 时必须 `revert`

接口：

- `post(chatGroupId, senderGroupId, content)`

说明：

- `content` 类型为 `string`
- 以 `bytes(content).length <= 16384` 作为约束
- `beforePost` 插件应保持轻量
- `MessagePost` 事件不带完整 `content`

验收条件：

- 不持有 `senderGroupId` 的地址不能冒用该身份发言
- 未挂 `beforePost` 的 `active` chat 仍允许跨群发言
- 协议不得额外拒绝 `senderGroupId != chatGroupId` 的消息
- 每条消息必须可追溯到具体 `chatGroupId`、`senderGroupId` 与 `senderAddress`

### 7.8 轮次与分页

- 群聊必须按轮次组织消息
- 轮次计算不依赖 `Join` 合约读值
- 部署 / 初始化时，应把 `originBlocks` 与 `phaseBlocks` 作为初始化参数写入
- 群聊协议本地按与 core `Phase` 一致公式计算 `currentRound()`
- `round` 编号从 `0` 开始
- `currentRound()` 的语义固定为 `roundByBlockNumber(block.number)`
- 对任意 `blockNumber >= originBlocks`，`roundByBlockNumber(blockNumber) = (blockNumber - originBlocks) / phaseBlocks`
- 因此第 `round` 轮覆盖的区块范围固定为 `[originBlocks + round * phaseBlocks, originBlocks + (round + 1) * phaseBlocks - 1]`
- 当 `block.number < originBlocks` 时，`currentRound()` 必须 `revert`
- 因 `post` 依赖 `currentRound()`，在 `originBlocks` 之前不得允许消息发送成功
- 查询接口命名风格统一仿照 core 协议，不使用 `get*`、`list*`、重载式双义命名
- 实际存储是 `chatGroupId` 下单一消息列表
- `round` 只标记该列表中的区间，形式是 `[startIndex, endIndex)`
- 协议只记录“有消息的 round”
- 空 round 不进入 `rounds(...)`
- 某 round 无消息时，`messagesByRoundCount(chatGroupId, round)` 返回 `0`
- 某 round 无消息时，`roundInfo(chatGroupId, round)` 不 `revert`，而是返回 `round = 入参`、`startIndex = 0`、`endIndex = 0`、`messageCount = 0`
- 不带 `round` 时，按 `chatGroupId` 对全量消息分页，顺序按 `messageIndex`
- 每个轮次内部必须支持分页查询
- 轮次列表也应支持分页查询
- `limit == 0` 时返回空数组，不 `revert`
- 分页越界返回空数组，不 `revert`
- `reverse = false` 表示旧到新
- `reverse = true` 表示新到旧

接口：

- `currentRound()`
- `messagesCount(chatGroupId)`
- `messagesByRoundCount(chatGroupId, round)`
- `messages(chatGroupId, offset, limit, reverse)`
- `messagesByRound(chatGroupId, round, offset, limit, reverse)`
- `roundsCount(chatGroupId)`
- `rounds(chatGroupId, offset, limit, reverse)`
- `roundInfo(chatGroupId, round)`

分页语义：

- `messages(chatGroupId, offset, limit, reverse)` 中 `offset` 为全局消息 offset
- `messagesByRound(chatGroupId, round, offset, limit, reverse)` 中 `offset` 为该 round 内 offset
- `rounds(chatGroupId, offset, limit, reverse)` 中 `offset` 为“有消息轮次列表”的分页位置，不是真实 `round` 编号

`rounds(...)` / `roundInfo(...)` 返回值应至少包含：

- `round`
- `startIndex`
- `endIndex`
- `messageCount`

说明：

- 返回 `startIndex` 与 `endIndex`，便于前端判断自己是否有新的或更老消息需要补拉

验收条件：

- 任意轮次都能分页读出完整消息
- 不传 `round` 也能分页读出该群全量消息
- 客户端应可通过 `messagesCount`、`roundInfo`、最新 `messageIndex` 判断是否有新消息
- 查询无需依赖中心化索引才可成立

### 7.9 插件系统

- 群聊必须支持插件合约
- MVP 只保留 `beforePost` 与 `afterPost` 两个独立 hook 槽位
- 每个 hook 槽位只允许挂载一个插件，不支持多插件链式执行
- `beforePost` 可拒绝消息发送
- `afterPost` 只能观察结果，不能修改已上链消息
- `beforePost` 与 `afterPost` 都使用 `call`
- `beforePost` 必须先于任何消息状态写入、`messageIndex` 分配与 `MessagePost` 事件发出执行
- 若 `beforePost` `revert`，则该次 `post` 必须整体 `revert`，且不得留下消息、事件或被占用的 `messageIndex`
- 不使用 `staticcall`
- 不使用 `delegatecall`
- 主协议不传 `ctx`
- 插件自己存状态
- 主协议不存 `configData`
- 单个插件合约可服务多个 `chatGroupId`
- 插件内部状态必须按 `chatGroupId` 自行隔离
- 插件配置权限默认锚定当前 chat 的 `owner` / 有效 `delegate`
- `beforePostPlugin` 与 `afterPostPlugin` 允许指向同一个插件合约，只要该合约同时实现所需 `hook`
- `beforePostPlugin` / `afterPostPlugin` 若非 `address(0)`，必须是已部署合约地址
- 对存在的 `GroupNFT`，若对应插件槽位当前未挂载，则 `beforePostPlugin(chatGroupId)` / `afterPostPlugin(chatGroupId)` 必须返回 `address(0)`，不 `revert`
- `activateChat`、`setBeforePostPlugin`、`setAfterPostPlugin` 在写入非零插件地址时，必须执行相同的合约地址校验
- 传入 EOA 或无代码地址作为插件地址时，必须 `revert`
- 将 `beforePostPlugin` 或 `afterPostPlugin` 重复设置为当前存储中的相同配置值时，必须 `revert`
- 任意成功改变 live 插件配置的交易，都必须让 `configVersion` 递增 1 次
- 若同一笔交易同时改动 `beforePostPlugin` 与 `afterPostPlugin`，`configVersion` 也只递增 1 次
- 主协议 `post` 必须 `nonReentrant`
- `afterPost` 失败不得回滚主消息，只能记录失败事件
- `beforePost` 成功即放行，`revert` 即拒绝

接口：

- `setBeforePostPlugin(chatGroupId, pluginAddress)`
- `setAfterPostPlugin(chatGroupId, pluginAddress)`
- `beforePostPlugin(chatGroupId)`
- `afterPostPlugin(chatGroupId)`

`hook` ABI：

```solidity
function beforePost(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress,
    string calldata content
) external;

function afterPost(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress,
    string calldata content,
    uint256 round,
    uint256 messageIndex,
    uint256 blockNumber,
    uint256 timestamp
) external;
```

验收条件：

- 插件应能限制哪些人能发消息
- 插件应能支持审核、同步、镜像等扩展
- 不同插件实现不得各自定义不兼容的 `beforePost` / `afterPost` 核心上下文字段

### 7.10 NFT 转让语义

- NFT 转让等同于群聊控制权转移
- 新 owner 接管群聊 `meta`、插件与管理权
- 历史消息、历史 `meta` 变化、历史事件不变
- 转让不得修改消息归属
- `owner` 必须始终实时读取，不缓存

实现要求：

- 转移后，`owner` 读值随 NFT 即时更新
- `delegate` 通过 `delegateOwnerSnapshot` 机制自动失效 / 自动恢复

验收条件：

- 转让前后群聊地址不变，控制人变化
- 历史内容保持完整

### 7.11 统一错误与零值规则

统一原则：

- 写接口统一规则：只要主体不存在、权限不满足、当前状态不允许、输入不合法、或本次调用不会改变当前 live 状态，都必须 `revert`
- 读接口统一规则：若目标 `GroupNFT` 不存在，必须 `revert`
- 读接口统一规则：若目标 `GroupNFT` 存在，但对应 live 子数据为空、目标项未命中、或分页越界，则应返回零值或空数组，不 `revert`

零值 / 空值约定：

- `chatInfo(groupId)` 对存在的 `GroupNFT` 必须返回结构体；尚未激活时返回未激活零值
- `metaValue(groupId, key)` 对当前不存在的 `key` 返回空 `bytes`
- `delegateOf(groupId)` 在无有效 `delegate` 时返回 `address(0)`
- `beforePostPlugin(chatGroupId)` / `afterPostPlugin(chatGroupId)` 在槽位未挂载时返回 `address(0)`
- `messagesByRoundCount(chatGroupId, round)` 对无消息 round 返回 `0`
- `roundInfo(chatGroupId, round)` 对无消息 round 不 `revert`，而是返回 `round = 入参`、`startIndex = 0`、`endIndex = 0`、`messageCount = 0`
- `metaEntries`、`messages`、`messagesByRound`、`rounds` 在 `limit == 0` 或分页越界时返回空数组

必须单独点名的输入校验：

- `post` 中 `bytes(content).length == 0` 时，必须 `revert`
- `post` 中 `bytes(content).length > 16384` 时，必须 `revert`
- `setMeta`、`setMetaBatch`、`activateChat` 的批量 `meta` 初始化中，若存在 `bytes(key).length == 0`，必须 `revert`
- `setDelegate` 中 `delegate == ownerOf(groupId)` 时，必须 `revert`
- `activateChat` 中 `metaKeys.length != metaValues.length` 时，必须 `revert`
- `setMetaBatch` 中 `keys.length != values.length` 时，必须 `revert`
- 同一笔 `activateChat` 或 `setMetaBatch` 的批量 `meta` 写入中，不允许重复 `key`
- 若批量 `meta` 写入中存在重复 `key`，必须 `revert`
- `activateChat`、`setBeforePostPlugin`、`setAfterPostPlugin` 在写入非零插件地址时，若地址无代码，必须 `revert`
- 所有批量写入接口必须先完成输入合法性校验，再执行任何状态变更与事件发出

## 8. 最小接口要求

以下接口为当前定稿的最小接口集合。实现必须覆盖等价能力：

- `activateChat`
- `deactivateChat`
- `chatInfo`
- `setMeta`
- `setMetaBatch`
- `metaValue`
- `metaEntries`
- `setDelegate`
- `delegateOf`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- `beforePostPlugin`
- `afterPostPlugin`
- `post`
- `currentRound`
- `messagesCount`
- `messagesByRoundCount`
- `messages`
- `messagesByRound`
- `roundsCount`
- `rounds`
- `roundInfo`

## 9. 数据与事件

### 9.1 必要事件

- `ChatActivate`
- `ChatDeactivate`
- `MetaSet`
- `DelegateSet`
- `BeforePostPluginSet`
- `AfterPostPluginSet`
- `MessagePost`
- `AfterPostPluginFailed`

### 9.2 事件字段要求

最终事件签名如下：

```solidity
event ChatActivate(
    uint256 indexed groupId,
    address indexed owner,
    uint256 configVersion
);

event ChatDeactivate(
    uint256 indexed groupId,
    address indexed owner,
    uint256 configVersion
);

event MetaSet(
    uint256 indexed groupId,
    address indexed operator,
    uint256 configVersion,
    string key,
    bytes value,
    bytes prevValue
);

event DelegateSet(
    uint256 indexed groupId,
    address indexed owner,
    address indexed delegate,
    uint256 configVersion,
    address prevDelegate
);

event BeforePostPluginSet(
    uint256 indexed groupId,
    address indexed pluginAddress,
    address indexed operator,
    uint256 configVersion,
    address prevPluginAddress
);

event AfterPostPluginSet(
    uint256 indexed groupId,
    address indexed pluginAddress,
    address indexed operator,
    uint256 configVersion,
    address prevPluginAddress
);

event MessagePost(
    uint256 indexed chatGroupId,
    uint256 indexed senderGroupId,
    address indexed senderAddress,
    uint256 configVersion,
    uint256 round,
    uint256 messageIndex
);

event AfterPostPluginFailed(
    uint256 indexed chatGroupId,
    uint256 indexed messageIndex,
    address indexed pluginAddress,
    uint256 configVersion,
    uint256 round,
    bytes errorData
);
```

说明：

- 任一成功的配置写交易若使 `configVersion` 递增，则该交易内所有配置差异事件都必须携带同一个新 `configVersion`
- `activateChat` 成功时，除 `ChatActivate` 外，还必须为实际发生变化的 `meta`、`delegate`、`beforePostPlugin`、`afterPostPlugin` 发出对应差异事件
- `deactivateChat` 成功时，只发出 `ChatDeactivate`
- `activateChat` 导致某个旧 `meta` key 被移除时，该移除必须视为一次删除，并发出 `MetaSet(..., value = bytes(\"\"), prevValue = oldValue)`
- `setMetaBatch` 发出的多条 `MetaSet` 事件顺序，必须与输入数组顺序一致
- `activateChat` 中对显式传入 `metaKeys/metaValues` 发出的多条 `MetaSet` 事件顺序，必须与输入数组顺序一致
- `ChatActivate` 应在同交易内所有配置差异事件之后发出，作为该次开启的汇总事件
- `ChatActivate` / `ChatDeactivate` 不带 `operator`
- 原因：只有 `owner` 可调用，`operator == owner`
- `ChatActivate` / `ChatDeactivate` 不带 `prevActive`
- 原因：事件名本身已表达状态切换动作
- `DelegateSet.prevDelegate` 语义固定为“本次修改前的有效 delegate”
- 因此它不一定等于修改前存储槽里的原始 `delegate` 配置值
- `MetaSet.prevValue` 语义固定为“本次修改前该 key 的有效值”
- 若本次修改前该 key 不存在，则 `MetaSet.prevValue = bytes(\"\")`
- `MetaSet.key` 不设为 `indexed`
- 原因：当前值查询应走 `metaValue` / `metaEntries`，不依赖日志按 key 过滤
- `BeforePostPluginSet.prevPluginAddress` 语义固定为“本次修改前生效中的 beforePost plugin”
- `AfterPostPluginSet.prevPluginAddress` 语义固定为“本次修改前生效中的 afterPost plugin”
- `MessagePost` 不带完整 `content`
- `MessagePost` 不带 `contentHash`
- `post` 成功时，必须先完成消息状态写入并发出 `MessagePost`，再执行 `afterPost`
- 若 `afterPost` 失败，`AfterPostPluginFailed` 必须在同一交易中、且位于 `MessagePost` 之后发出
- `AfterPostPluginFailed` 用于定位失败插件对应的已落链消息
- 前端收到 `AfterPostPluginFailed` 后，应使用 `messages(chatGroupId, messageIndex, 1, false)` 回查该条消息

### 9.3 索引与同步要求

- 必须支持按 `groupId` 查询 chat
- 必须支持按 `chatGroupId + round` 查询该轮消息区间
- 必须支持按 `chatGroupId` 查询消息分页
- 必须支持不传 `round` 查询 `chatGroupId` 下全量消息分页
- 前端消息同步要求：
- 只把 `MessagePost` 当作“发现新消息”的信号
- 正文内容始终以 `messages(...)` / `messagesByRound(...)` 的 `view` 结果为准
- 本地应维护每个 `chatGroupId` 的最新 `messageIndex` 游标
- 收到 `MessagePost` 后：
- 若 `messageIndex == latestMessageIndex + 1`，应使用 `messages(chatGroupId, messageIndex, 1, false)` 拉取该条消息
- 若 `messageIndex > latestMessageIndex + 1`，说明存在缺口，应按缺口区间补拉
- 前端配置同步要求：
- 只把 `ChatActivate`、`ChatDeactivate`、`MetaSet`、`DelegateSet`、`BeforePostPluginSet`、`AfterPostPluginSet` 当作“配置已变更”的信号
- 本地应维护每个 `chatGroupId` 的 `configVersion` 缓存
- 收到任一配置事件后：
- 若事件里的 `configVersion` 大于本地缓存，应直接全量重拉当前配置
- 配置全量重拉应至少覆盖：`chatInfo`、`metaEntries`、`delegateOf`、`beforePostPlugin`、`afterPostPlugin`
- owner 同步要求：
- `owner` 不属于 `configVersion` 覆盖范围
- 前端若关心当前管理权限，必须以 `chatInfo(groupId).owner`、`GroupNFT.ownerOf(groupId)` 或 `GroupNFT` 的 `Transfer` 事件为准
- 首次进入 / 重连 / 刷新后：
- 应先读取 `chatInfo(groupId)` 并对比本地 `configVersion`
- 再读取 `messagesCount(chatGroupId)` 并对比本地 `latestMessageIndex`
- 若任一不一致，应执行对应的配置全量重拉或消息缺口补拉
- 前端不应依赖事件增量重放来拼装最终 live 配置
- 事件只负责发现变化
- 当前配置与当前消息正文都应以 `view` 读取结果为真值

## 10. 非功能要求

### 10.1 去中心化

- 无升级管理员
- 无后门
- 无中心化审核开关
- 无特权恢复口

### 10.2 安全

- 管理类写接口必须做 `owner` / 有效 `delegate` / `active` 校验
- `activateChat`、`deactivateChat` 必须只允许 `owner`
- 发消息接口必须做 `owner` / plugin 校验，不得接受 `delegate` 冒充发言身份
- 插件不能越权修改核心状态
- 代理配置要防止对错误 owner 生效
- 消息内容要有明确长度上限
- `post` 与插件交互过程要防重入

### 10.3 可扩展

- 协议状态尽量少
- 新功能优先通过 `meta` 与 `plugin` 扩展
- 不把子频道、成员表、复杂治理塞进协议

### 10.4 可组合

- 群聊可引用其他群聊
- 群聊可引用 LOVE20 代币、治理、行动信息
- 群聊可作为行动、治理、服务统一承载层
- 首次激活快照可用于识别某群最初是否由治理管理合约激活

### 10.5 可维护

- 历史数据必须可分页读取
- 事件必须足够给前端和索引器使用
- 状态必须与事件一致
- 前端不得把事件当作正文真源

## 11. 协议边界

### 11.1 协议只做

- 身份
- 控制权
- `meta`
- 插件挂载
- 消息
- 轮次

### 11.2 协议不做

- 子频道树
- 成员表
- 私聊
- 删除消息
- 投票审批
- 链下同步
- 插件统一配置中心

## 12. 验收标准

协议可视为完成，需同时满足：

- 任何人都能读取任意 chat 历史消息
- `GroupNFT` owner 能激活、关闭并管理对应 chat
- `delegate` 只能在授权范围内代管，不能发言、不能激活、不能关闭
- NFT 转让后控制权自动变化
- NFT 转回原 owner 后，旧 delegate 自动恢复
- 消息全量上链且不可改写
- 未挂 `beforePost` 时默认允许跨群发言
- `meta` 能被设置、批量设置、删除、读取、分页枚举
- 插件能限制发言但不能破坏核心不可变性
- `afterPost` 失败不影响主消息落链
- 无成员表也能完成全部公开群聊需求
