# Group Chat 需求文档

- 模块：Group Chat 协议
- 状态：草案
- 目标：基于 `GroupNFT` 的完全链上公开群聊协议
- 版本：v0.1

## 1. 背景

LOVE20 现有协议里，`GroupNFT` 更接近链上身份账号 / 链上自媒体账号。群聊协议应直接复用这层身份，不再引入中心化账号系统，也不做成员表、私聊门禁或链下托管。

本协议核心判断：

- 链上公开消息天然可读
- 群聊不需要“谁能看”
- 群聊只需要“谁能发”和“谁能管”
- NFT 转让应等价于群聊控制权转让
- 地址只是当前控制某个身份 NFT 的签名器，不是长期身份主体

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

每个 `GroupNFT` 对应一个身份主体，并默认可激活一个公开群聊。`owner` 是动态概念，始终等于当前 `ownerOf(groupId)`。

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
| GroupNFT | 已部署且不可 burn 的 `LOVE20Group` 身份 NFT，作为链上身份账号 / 链上自媒体账号；本文不抽象支持其他 ERC721 身份源 |
| Chat | 由某个 `GroupNFT` 激活出的公开群聊能力 |
| groupId | 群聊唯一标识，直接使用 `GroupNFT` 编号 |
| chatGroupId | 消息所属群聊标识，等于所属 chat 的 `groupId` |
| senderGroupId | 发消息时使用的身份 `GroupNFT` 编号，可与 `chatGroupId` 相同或不同 |
| senderAddress | 实际发起交易地址，必须是 `senderGroupId` 当前 owner；可作为辅助风控主体，但不是长期身份主体 |
| owner | 当前持有该 `GroupNFT` 的地址，实时变化 |
| delegateGroupId | 由 owner 设置、仅可代行群管理的身份 `GroupNFT`；其当前 owner 可执行被授权管理操作，但不可代替 `senderGroupId` 发言 |
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
- 设置 / 清空代理身份
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
- `configVersion` 覆盖范围包括：`active`、`meta`、`delegateGroupId` 原始存储配置、`beforePostPlugin`、`afterPostPlugin`
- `configVersion` 不覆盖：实时 `owner`、消息、`firstActivated*`
- `configVersion` 不覆盖：随 `owner` 变化派生出的当前有效 `delegateGroupId`
- 前端可通过比较缓存值与 `chatInfo(groupId)` 返回的 `configVersion` 判断是否需要全量刷新配置缓存
- `chatInfo(groupId)` 必须返回与本节 `Chat` 定义一致的结构体或等价 tuple，字段顺序按本节顺序固定

### 6.2 Message

每条消息至少包含：

- `chatGroupId`
- `senderGroupId`
- `senderAddress`
- `round`
- `messageIndex`，该群聊内全局消息序号，从 `0` 开始
- `content`
- `blockNumber`
- `timestamp`

实际存储模型：

- 每个 `chatGroupId` 下只有一条追加式消息列表
- `messageIndex` 以整个群聊消息列表为准，不按 `round` 重置
- `round` 只标记这条全局列表里哪一段属于该轮
- `messages(...)`、`messagesByRound(...)` 与 `messagesBySender(...)` 必须返回与本节 `Message` 定义一致的结构体数组或等价 tuple 数组，字段顺序按本节顺序固定

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

### 6.5 DelegateGroup

每个 chat 至少包含一组代理状态：

- `delegateGroupId`
- `delegateOwnerSnapshot`

说明：

- `delegateGroupId` 是被授权代管该 chat 的身份 NFT
- 当前真正可执行代管操作的，是 `delegateGroupId` 的当前 owner
- `delegateGroupId` 仅在 `delegateOwnerSnapshot == ownerOf(groupId)` 时有效
- `delegateOwnerSnapshot` 只是旧 owner 绑定快照，不是被授权主体
- NFT 转给别人后，旧 `delegateGroupId` 对新 owner 立即失效
- NFT 转回同一 owner 后，旧 `delegateGroupId` 自动恢复
- `delegateGroupIdOf(groupId)` 属于运行时派生读值，不属于 `configVersion` 覆盖范围

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
- `active = false` 时，主协议内唯一允许的 live 配置写操作是 `activateChat`
- `active = false` 时，禁止 `setMeta`
- `active = false` 时，禁止 `setMetaBatch`
- `active = false` 时，禁止 `setDelegateGroupId`
- `active = false` 时，禁止 `setBeforePostPlugin`
- `active = false` 时，禁止 `setAfterPostPlugin`
- `active = false` 时，若某插件已挂载，允许该插件自身的内部配置写操作
- `deactivateChat` 不得清空当前 `meta`、`delegateGroupId`、`beforePostPlugin`、`afterPostPlugin`
- 群聊处于关闭态时，相关只读接口仍必须返回当前存储配置
- 关闭状态不影响历史消息读取
- 恢复后继续使用同一 `groupId` 与同一历史消息

接口：

- `activateChat(groupId, metaKeys, metaValues, beforePostPlugin, afterPostPlugin, delegateGroupId_)`
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
- 重新 `activateChat` 时，旧 live `meta` 中本次未显式传入的 `key` 视为删除
- 重新 `activateChat` 时，旧 live 中继续保留且本次仍传入的 `key`，必须保持其在当前 live 列表中的原相对顺序
- 重新 `activateChat` 时，本次新增的 `key`，必须按本次输入顺序追加到当前 live 列表尾部
- 重新 `activateChat` 时，同名 `key` 若本次 `value` 与旧值相同，视为保留，不构成 `MetaSet` 差异事件
- 重新 `activateChat` 时，同名 `key` 若本次 `value` 与旧值不同，视为更新
- 任意成功改变 live 配置的交易，都必须让 `configVersion` 递增 1 次
- `activateChat`、`deactivateChat`、`setMeta`、`setMetaBatch`、`setDelegateGroupId`、`setBeforePostPlugin`、`setAfterPostPlugin` 都属于 live 配置变更
- 同一笔交易里即使同时改多个配置项，`configVersion` 也只递增 1 次
- `metaValue` 与 `metaEntries` 始终只返回当前 live `meta`
- 历史 `meta` 变化仍通过事件追踪，不要求链上保留旧版本可读快照
- 重新 `activateChat` 时，`beforePostPlugin` / `afterPostPlugin` / `delegateGroupId_` 都按本次入参直接覆盖
- `beforePostPlugin = address(0)` 表示清空
- `afterPostPlugin = address(0)` 表示清空
- `delegateGroupId_ = 0` 表示清空

验收条件：

- 未持有 NFT 的地址不能激活或关闭
- `delegateGroupId` 当前 owner 不能激活或关闭
- 非法状态切换必须 `revert`
- 关闭不会清空任何历史

### 7.3 主键

- `groupId` 直接等于 `GroupNFT` 的 `tokenId`
- `chat`、`meta`、`delegateGroupId`、插件状态都挂在 `groupId` 下
- 消息与轮次分页按 `chatGroupId` 归属
- `chatGroupId` 恒等于所属 chat 的 `groupId`
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

- `owner` 与有效 `delegateGroupId` 当前 owner 可写 `meta`
- 应支持通过 `meta` 挂任意外部引用
- 删除语义明确且可观测

### 7.5 群聊状态

- 群聊仅区分两种运行态：
- `active = true`
- `active = false`
- 协议不引入额外“已关闭但曾激活过”的独立枚举状态
- “曾被首次激活过”通过 `firstActivated*` 判断，不通过额外状态枚举判断
- `active = false` 时禁止发消息
- `active = false` 时禁止除 `activateChat` 与已挂载插件内部配置写外的管理写操作

验收条件：

- 前端仅通过 `active` 即可判断当前是否可发言 / 可管理
- 若需要判断“是否曾激活过”，可直接读取 `firstActivatedBlockNumber != 0`

### 7.6 代理身份机制

- 当前 `owner` 可设置 `delegateGroupId`
- `delegateGroupId` 仅可代行群管理，不可代替 `senderGroupId` 发言
- 当前真正执行管理操作的地址，必须是 `delegateGroupId` 的当前 owner
- `delegateGroupId` 可执行：
- `setMeta`
- `setMetaBatch`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- 插件内部配置写操作
- `delegateGroupId` 不可执行：
- `activateChat`
- `deactivateChat`
- 使用任意 `senderGroupId` 发言
- `delegateGroupId == groupId` 不允许；设置为 chat 自己时必须 `revert`
- 仅当本次 `setDelegateGroupId` 不会改变当前存储态时，才允许视为重复设置并 `revert`
- 代理状态必须可查询
- 代理配置必须可清空
- `setDelegateGroupId(groupId, 0)` 表示清空当前存储的 `delegateGroupId` 配置
- `setDelegateGroupId(groupId, 0)` 时，必须同时清空 `delegateOwnerSnapshot`
- `deactivateChat` 不清空 `delegateGroupId`
- `delegateGroupId` 有效条件必须绑定当前 `owner`

接口：

- `setDelegateGroupId(groupId, delegateGroupId)`
- `delegateGroupIdOf(groupId)`

说明：

- `delegateGroupIdOf(groupId)` 必须返回当前有效的 `delegateGroupId`
- 若当前存储的 `delegateOwnerSnapshot != ownerOf(groupId)`，则 `delegateGroupIdOf(groupId)` 必须返回 `0`
- 当 NFT 转回与 `delegateOwnerSnapshot` 相同的 owner 时，`delegateGroupIdOf(groupId)` 必须再次返回原先配置的 `delegateGroupId`
- `setDelegateGroupId(groupId, delegateGroupId)` 的 no-op 判定必须基于当前存储态，而不是仅基于 `delegateGroupIdOf(groupId)` 的派生结果

验收条件：

- NFT 转移后，旧 `delegateGroupId` 对新 owner 立即失效
- NFT 转回同一 owner 后，旧 `delegateGroupId` 自动恢复
- `delegateGroupId` 不能绕过 `active` 状态
- `delegateGroupId` 不能代替 owner 作为 `senderGroupId` 发消息

### 7.7 发消息

- 发消息时必须同时指定 `chatGroupId` 与 `senderGroupId`
- `senderGroupId` 表示发言身份，可与 `chatGroupId` 相同或不同
- `senderAddress` 为实际调用地址，也是可选的辅助风控主体
- `msg.sender` 必须是 `senderGroupId` 当前 owner
- `delegateGroupId` 当前 owner 不得代替 `senderGroupId` owner 发消息
- `chatGroupId` 对应 chat 必须处于 `active`
- `senderGroupId` 必须对应一个当前存在的 `GroupNFT`
- 不要求 `senderGroupId` 自己的 chat 已激活
- 是否允许 `senderGroupId` 向 `chatGroupId` 发消息，由该 chat 的插件或外部规则决定
- `mentions` 用于声明本条消息提及的 `GroupNFT` 身份列表
- `mentions` 数量上限固定为 `32`
- `mentions` 中每个 `mentionedGroupId` 都必须当前存在
- `mentions` 中不得出现重复 `mentionedGroupId`
- `mentions` 允许包含 `senderGroupId` 自己
- `mentionAll` 仅表示消息声明了“@all”语义
- `mentionAll=true` 时允许同时携带具体 `mentions`
- 主协议必须原样记录并透传 `mentionAll`
- 是否允许 `mentionAll`，由 `beforePost` 插件或外部规则决定；主协议不做额外判定
- 主协议必须支持消息引用字段 `quotedMessageIndex`
- `quotedMessageIndex == 0` 表示无引用
- `quotedMessageIndex > 0` 时，必须引用当前 `chatGroupId` 内一条已存在历史消息
- 为保持语义简单，协议不支持引用 `messageIndex == 0` 的消息
- `quotedMessageIndex` 的合法性必须由主协议校验，并且校验发生在 `beforePost` 之前
- 若未配置 `beforePost` 插件，则在通过 owner、`active`、内容长度等核心校验后默认允许发送
- 协议默认规则不得要求 `senderGroupId == chatGroupId`
- 消息内容必须完整上链
- 单次 `post` 只发 1 条消息，不做批量消息接口
- 消息只能新增，不能编辑或删除
- 空消息不允许发送；`bytes(content).length == 0` 时必须 `revert`
- 单条消息内容长度上限固定为 `16384` bytes
- `bytes(content).length > 16384` 时必须 `revert`

接口：

- `post(chatGroupId, senderGroupId, content, mentions, mentionAll, quotedMessageIndex)`
- `postByDefaultSender(chatGroupId, content, mentions, mentionAll, quotedMessageIndex)`
- `setDefaultSenderGroupId(senderGroupId)`
- `clearDefaultSenderGroupId()`
- `defaultSenderGroupIdOf(account)`

说明：

- `content` 类型为 `string`
- `mentions` 类型为 `uint256[]`
- `mentionAll` 类型为 `bool`
- `quotedMessageIndex` 类型为 `uint256`
- 以 `bytes(content).length <= 16384` 作为约束
- 以 `mentions.length <= 32` 作为约束
- `beforePost` 插件应保持轻量
- `MessagePost` 事件不带完整 `content`
- 默认发言身份是全局地址级便捷状态，不属于任何 chat 的 `configVersion`
- `defaultSenderGroupIdOf(account)` 返回当前有效默认身份；未设置或已失效都返回 `0`
- `postByDefaultSender(...)` 只是 `post(...)` 的语法糖，先解析当前有效默认身份，再复用普通发消息流程
- `clearDefaultSenderGroupId()` 基于原始存储判定是否可清理，而不是基于 `defaultSenderGroupIdOf(account)` 的派生结果

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
- 协议必须支持在单个 `chatGroupId` 内，按 `senderGroupId` 过滤该发送身份的全量消息并分页读取
- `messagesBySender(...)` 的结果范围是目标 `chatGroupId` 下、`senderGroupId` 命中的全部消息，不额外按 `round` 再分段
- 协议应同时提供对应的轻量索引接口 `messageIndexesBySender(...)`
- `messageIndexesBySender(...)` 必须返回与 `messagesBySender(...)` 同一命中集合、同一顺序下的 `messageIndex` 数组
- 协议必须支持在单个 `chatGroupId` 内，按被提及身份 `mentionedGroupId` 过滤命中消息并分页读取
- `messagesByMention(...)` 的结果范围是目标 `chatGroupId` 下、`mentionedGroupId` 命中的全部消息，不额外按 `round` 再分段
- 协议应同时提供对应的轻量索引接口 `messageIndexesByMention(...)`
- `messageIndexesByMention(...)` 必须返回与 `messagesByMention(...)` 同一命中集合、同一顺序下的 `messageIndex` 数组
- 协议必须支持在单个 `chatGroupId` 内，按 `mentionAll = true` 过滤命中消息并分页读取
- 协议应同时提供对应的轻量索引接口 `messageIndexesByMentionAll(...)`
- `messageIndexesByMentionAll(...)` 必须返回与 `messagesByMentionAll(...)` 同一命中集合、同一顺序下的 `messageIndex` 数组
- 协议应提供该群已发言 `senderGroupId` 列表的分页查询接口
- 某 `senderGroupId` 在该 `chatGroupId` 内首次发言时，必须进入 `senderGroupIds(...)` 当前 live 列表
- 同一 `senderGroupId` 后续再次发言时，不得改变其在 `senderGroupIds(...)` 当前 live 列表中的位置
- `senderGroupIds(..., reverse = false)` 必须按首次发言进入列表的顺序从旧到新返回
- `senderGroupIds(..., reverse = true)` 必须按首次发言进入列表的顺序从新到旧返回
- 空 round 不进入 `rounds(...)`
- 某 round 无消息时，`messagesByRoundCount(chatGroupId, round)` 返回 `0`
- 某 `senderGroupId` 在该群无消息时，`messagesBySenderCount(chatGroupId, senderGroupId)` 返回 `0`
- `messagesBySender*` 中的 `senderGroupId` 仅作为过滤条件；即使传入的 `senderGroupId` 当前在 `LOVE20Group` 中不存在，未命中时也返回 `0` 或空数组，不额外 `revert`
- 某 round 无消息时，`roundInfo(chatGroupId, round)` 不 `revert`，而是返回 `round = 入参`、`startIndex = 0`、`endIndex = 0`、`messageCount = 0`
- 不带 `round` 时，按 `chatGroupId` 对全量消息分页，顺序按 `messageIndex`
- 按发送者过滤时，按命中消息的 `messageIndex` 顺序分页
- 每个轮次内部必须支持分页查询
- 每个发送者维度也必须支持分页查询
- 轮次列表也应支持分页查询
- `limit == 0` 时返回空数组，不 `revert`
- 分页越界返回空数组，不 `revert`
- `reverse = false` 表示旧到新
- `reverse = true` 表示新到旧
- 所有分页接口的 `offset` 都必须以最终返回顺序为基准
- 因此 `reverse = false` 时，`offset = 0` 对应最旧元素
- 因此 `reverse = true` 时，`offset = 0` 对应最新元素

接口：

- `currentRound()`
- `messagesCount(chatGroupId)`
- `message(chatGroupId, messageIndex)`
- `messagesByRoundCount(chatGroupId, round)`
- `messagesBySenderCount(chatGroupId, senderGroupId)`
- `messagesByMentionCount(chatGroupId, mentionedGroupId)`
- `messagesByMentionAllCount(chatGroupId)`
- `senderGroupIdsCount(chatGroupId)`
- `messages(chatGroupId, offset, limit, reverse)`
- `messagesByRound(chatGroupId, round, offset, limit, reverse)`
- `messagesBySender(chatGroupId, senderGroupId, offset, limit, reverse)`
- `messageIndexesBySender(chatGroupId, senderGroupId, offset, limit, reverse)`
- `messagesByMention(chatGroupId, mentionedGroupId, offset, limit, reverse)`
- `messageIndexesByMention(chatGroupId, mentionedGroupId, offset, limit, reverse)`
- `messagesByMentionAll(chatGroupId, offset, limit, reverse)`
- `messageIndexesByMentionAll(chatGroupId, offset, limit, reverse)`
- `senderGroupIds(chatGroupId, offset, limit, reverse)`
- `roundsCount(chatGroupId)`
- `rounds(chatGroupId, offset, limit, reverse)`
- `roundInfo(chatGroupId, round)`

分页语义：

- `messages(chatGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的全局消息 offset
- `messagesByRound(chatGroupId, round, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该 round 内 offset
- `messagesBySender(chatGroupId, senderGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该发送者命中消息列表内 offset
- `messageIndexesBySender(chatGroupId, senderGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该发送者命中消息索引列表内 offset
- `messagesByMention(chatGroupId, mentionedGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该提及命中消息列表内 offset
- `messageIndexesByMention(chatGroupId, mentionedGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该提及命中消息索引列表内 offset
- `messagesByMentionAll(chatGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的 `mentionAll=true` 命中消息列表内 offset
- `messageIndexesByMentionAll(chatGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的 `mentionAll=true` 命中消息索引列表内 offset
- `senderGroupIds(chatGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的该群已发言 `senderGroupId` 列表内 offset
- `rounds(chatGroupId, offset, limit, reverse)` 中 `offset` 为所选返回方向下的“有消息轮次列表”分页位置，不是真实 `round` 编号

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
- 传入 `senderGroupId` 时也能分页读出该身份在该群发出的全部消息
- 传入 `senderGroupId` 时也能分页读出该身份在该群发言对应的 `messageIndex` 列表
- 传入 `mentionedGroupId` 时也能分页读出提及该身份的全部消息
- 传入 `mentionedGroupId` 时也能分页读出提及该身份对应的 `messageIndex` 列表
- 客户端也能分页读出该群所有 `mentionAll=true` 的消息
- 客户端也能分页读出该群所有 `mentionAll=true` 对应的 `messageIndex` 列表
- 客户端也能分页读出该群所有已发言过的 `senderGroupId` 列表
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
- 主协议必须把 `mentions`、`mentionAll` 与 `quotedMessageIndex` 原样传给 `beforePost` / `afterPost`
- `mentionAll` 的允许性由插件自行判断；主协议不做额外许可判定
- 不使用 `staticcall`
- 不使用 `delegatecall`
- 主协议不传 `ctx`
- 插件自己存状态
- 主协议不存 `configData`
- 单个插件合约可服务多个 `chatGroupId`
- 插件内部状态必须按 `chatGroupId` 自行隔离
- 插件配置权限默认锚定当前 chat 的 `owner` / 有效 `delegateGroupId` 当前 owner
- 插件内部配置写接口必须显式接收 `chatGroupId`
- 插件内部配置写权限校验必须实时基于当前 chat 的 `owner` 与 `delegateGroupIdOf(chatGroupId)`
- `active = false` 不阻止已挂载插件的内部配置写；是否最终允许，由插件自身规则决定
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
    string calldata content,
    uint256[] calldata mentions,
    bool mentionAll,
    uint256 quotedMessageIndex
) external;

function afterPost(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress,
    string calldata content,
    uint256[] calldata mentions,
    bool mentionAll,
    uint256 quotedMessageIndex,
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
- `delegateGroupId` 通过 `delegateOwnerSnapshot` 机制自动失效 / 自动恢复

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
- `delegateGroupIdOf(groupId)` 在无有效 `delegateGroupId` 时返回 `0`
- `beforePostPlugin(chatGroupId)` / `afterPostPlugin(chatGroupId)` 在槽位未挂载时返回 `address(0)`
- `defaultSenderGroupIdOf(account)` 在未设置或已失效时返回 `0`
- `message(chatGroupId, messageIndex)` 在 `messageIndex` 越界时必须 `revert`
- `messagesByRoundCount(chatGroupId, round)` 对无消息 round 返回 `0`
- `messagesBySenderCount(chatGroupId, senderGroupId)` 对该发送身份无消息时返回 `0`
- `senderGroupIdsCount(chatGroupId)` 对尚无任何发言身份时返回 `0`
- `roundInfo(chatGroupId, round)` 对无消息 round 不 `revert`，而是返回 `round = 入参`、`startIndex = 0`、`endIndex = 0`、`messageCount = 0`
- `metaEntries`、`messages`、`messagesByRound`、`messagesBySender`、`messageIndexesBySender`、`senderGroupIds`、`rounds` 在 `limit == 0` 或分页越界时返回空数组

必须单独点名的输入校验：

- `post` 中 `bytes(content).length == 0` 时，必须 `revert`
- `post` 中 `bytes(content).length > 16384` 时，必须 `revert`
- `post` 中 `mentions.length > 32` 时，必须 `revert`
- `setMeta`、`setMetaBatch`、`activateChat` 的批量 `meta` 初始化中，若存在 `bytes(key).length == 0`，必须 `revert`
- `setDelegateGroupId` 中 `delegateGroupId == groupId` 时，必须 `revert`
- `setDelegateGroupId` 中，若当前存储的 `delegateGroupId` 与 `delegateOwnerSnapshot` 已与本次目标存储态完全相同，必须 `revert`
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
- `setDelegateGroupId`
- `delegateGroupIdOf`
- `setBeforePostPlugin`
- `setAfterPostPlugin`
- `beforePostPlugin`
- `afterPostPlugin`
- `post`
- `postByDefaultSender`
- `setDefaultSenderGroupId`
- `clearDefaultSenderGroupId`
- `defaultSenderGroupIdOf`
- `currentRound`
- `messagesCount`
- `message`
- `messagesByRoundCount`
- `messagesBySenderCount`
- `senderGroupIdsCount`
- `messages`
- `messagesByRound`
- `messagesBySender`
- `messageIndexesBySender`
- `senderGroupIds`
- `roundsCount`
- `rounds`
- `roundInfo`

### 8.1 建议接口命名与拆分

为与 LOVE20 现有仓库风格保持一致，建议采用以下拆分：

- `IGroupChatStructs`
- `IGroupChatErrors`
- `IGroupChatEvents`
- `IGroupChat`
- `GroupChat`

其中：

- `IGroupChatStructs` 仅放对外返回的结构体定义
- `IGroupChatErrors` 仅放自定义错误
- `IGroupChatEvents` 仅放事件
- `IGroupChat` 组合以上接口并声明函数
- `GroupChat` 为最终实现合约

### 8.2 建议对外结构体

建议固定以下结构体字段顺序：

```solidity
struct ChatInfo {
    uint256 groupId;
    address owner;
    bool active;
    uint256 configVersion;
    address firstActivatedOwner;
    uint256 firstActivatedBlockNumber;
    uint256 firstActivatedTimestamp;
}

struct Message {
    uint256 chatGroupId;
    uint256 senderGroupId;
    address senderAddress;
    uint256 round;
    uint256 messageIndex;
    string content;
    uint256 blockNumber;
    uint256 timestamp;
    uint256[] mentions;
    bool mentionAll;
    uint256 quotedMessageIndex;
}

struct RoundSpan {
    uint256 round;
    uint256 startIndex;
    uint256 endIndex;
    uint256 messageCount;
}

struct MetaEntry {
    string key;
    bytes value;
}
```

### 8.3 建议接口签名

建议主接口至少采用以下签名：

```solidity
function activateChat(
    uint256 groupId,
    string[] calldata metaKeys,
    bytes[] calldata metaValues,
    address beforePostPlugin_,
    address afterPostPlugin_,
    uint256 delegateGroupId_
) external;

function deactivateChat(uint256 groupId) external;

function setMeta(
    uint256 groupId,
    string calldata key,
    bytes calldata value
) external;

function setMetaBatch(
    uint256 groupId,
    string[] calldata keys,
    bytes[] calldata values
) external;

function setDelegateGroupId(
    uint256 groupId,
    uint256 delegateGroupId_
) external;

function setBeforePostPlugin(
    uint256 groupId,
    address pluginAddress
) external;

function setAfterPostPlugin(
    uint256 groupId,
    address pluginAddress
) external;

function post(
    uint256 chatGroupId,
    uint256 senderGroupId,
    string calldata content,
    uint256[] calldata mentions,
    bool mentionAll,
    uint256 quotedMessageIndex
) external;

function postByDefaultSender(
    uint256 chatGroupId,
    string calldata content,
    uint256[] calldata mentions,
    bool mentionAll,
    uint256 quotedMessageIndex
) external;

function setDefaultSenderGroupId(uint256 senderGroupId) external;

function clearDefaultSenderGroupId() external;

function chatInfo(uint256 groupId) external view returns (ChatInfo memory);

function metaValue(
    uint256 groupId,
    string calldata key
) external view returns (bytes memory);

function metaEntries(
    uint256 groupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (MetaEntry[] memory);

function delegateGroupIdOf(uint256 groupId) external view returns (uint256);

function beforePostPlugin(uint256 groupId) external view returns (address);

function afterPostPlugin(uint256 groupId) external view returns (address);

function defaultSenderGroupIdOf(address account) external view returns (uint256);

function currentRound() external view returns (uint256);

function messagesCount(uint256 chatGroupId) external view returns (uint256);

function message(
    uint256 chatGroupId,
    uint256 messageIndex
) external view returns (Message memory);

function messagesByRoundCount(
    uint256 chatGroupId,
    uint256 round
) external view returns (uint256);

function messagesBySenderCount(
    uint256 chatGroupId,
    uint256 senderGroupId
) external view returns (uint256);

function messagesByMentionCount(
    uint256 chatGroupId,
    uint256 mentionedGroupId
) external view returns (uint256);

function messagesByMentionAllCount(
    uint256 chatGroupId
) external view returns (uint256);

function senderGroupIdsCount(
    uint256 chatGroupId
) external view returns (uint256);

function messages(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (Message[] memory);

function messagesByRound(
    uint256 chatGroupId,
    uint256 round,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (Message[] memory);

function messagesBySender(
    uint256 chatGroupId,
    uint256 senderGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (Message[] memory);

function messageIndexesBySender(
    uint256 chatGroupId,
    uint256 senderGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (uint256[] memory);

function messagesByMention(
    uint256 chatGroupId,
    uint256 mentionedGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (Message[] memory);

function messageIndexesByMention(
    uint256 chatGroupId,
    uint256 mentionedGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (uint256[] memory);

function messagesByMentionAll(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (Message[] memory);

function messageIndexesByMentionAll(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (uint256[] memory);

function senderGroupIds(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (uint256[] memory);

function roundsCount(uint256 chatGroupId) external view returns (uint256);

function rounds(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit,
    bool reverse
) external view returns (RoundSpan[] memory);

function roundInfo(
    uint256 chatGroupId,
    uint256 round
) external view returns (RoundSpan memory);
```

说明：

- 入参命名中仅在需要避开状态变量重名时使用下划线后缀
- `chatInfo` 返回类型建议直接命名为 `ChatInfo`
- `messages` / `messagesByRound` / `messagesBySender` / `rounds` 建议直接返回结构体数组，不再拆成多数组返回
- `messageIndexesBySender` 作为轻量辅助接口，建议只返回 `messageIndex` 数组
- `messagesByMention` / `messagesByMentionAll` 建议直接返回结构体数组
- `messageIndexesByMention` / `messageIndexesByMentionAll` 作为轻量辅助接口，建议只返回 `messageIndex` 数组
- `senderGroupIds` 作为发言身份列表接口，建议只返回 `senderGroupId` 数组

### 8.4 建议自定义错误

建议至少定义以下主协议错误：

```solidity
error GroupNotExist();
error ChatAlreadyActive();
error ChatAlreadyInactive();
error ChatNotActive();
error NotChatOwner();
error NotChatOwnerOrDelegateGroupOwner();
error SenderNotGroupOwner();
error RoundNotStarted();
error MetaKeyEmpty();
error MetaArrayLengthMismatch();
error DuplicateMetaKey();
error MetaValueUnchanged();
error MetaKeyNotFound();
error DelegateGroupIdCannotBeChatGroupId();
error DelegateGroupIdUnchanged();
error PluginAddressHasNoCode();
error PluginAddressUnchanged();
error ContentEmpty();
error ContentTooLong(uint256 length, uint256 maxLength);
error TooManyMentions(uint256 length, uint256 maxLength);
error DuplicateMentionGroupId();
error InvalidQuotedMessageIndex();
error InvalidMessageIndex();
error DefaultSenderGroupIdNotSet();
error DefaultSenderGroupIdAlreadySet(uint256 senderGroupId);
error DefaultSenderGroupIdNotStored();
```

建议语义：

- `GroupNotExist`：目标 `LOVE20Group.ownerOf(groupId)` 不存在
- `ChatAlreadyActive` / `ChatAlreadyInactive`：非法状态切换
- `ChatNotActive`：关闭态下调用要求 chat 处于开启态的写接口或 `post`
- `NotChatOwner`：仅 owner 可执行的接口被非 owner 调用
- `NotChatOwnerOrDelegateGroupOwner`：要求当前 owner 或有效 `delegateGroupId` 当前 owner 的接口被未授权地址调用
- `SenderNotGroupOwner`：`post` 时 `msg.sender` 不是 `senderGroupId` 当前 owner
- `RoundNotStarted`：当前区块尚未到 `originBlocks`
- `MetaKeyEmpty` / `MetaArrayLengthMismatch` / `DuplicateMetaKey`：`meta` 输入不合法
- `MetaValueUnchanged` / `MetaKeyNotFound`：`meta` 写入不会改变 live 状态
- `DelegateGroupIdCannotBeChatGroupId` / `DelegateGroupIdUnchanged`：代理身份写入不合法或不会改变当前存储态
- `DuplicateMentionGroupId`：`mentions` 中出现重复身份
- `TooManyMentions`：`mentions` 超过固定上限 `32`
- `PluginAddressHasNoCode` / `PluginAddressUnchanged`：插件地址不合法或不会改变当前 live 配置
- `ContentEmpty` / `ContentTooLong`：消息内容不合法
- `InvalidQuotedMessageIndex`：引用目标不存在或越界
- `InvalidMessageIndex`：单条消息读取越界
- `DefaultSenderGroupIdNotSet` / `DefaultSenderGroupIdAlreadySet` / `DefaultSenderGroupIdNotStored`：默认发言身份相关状态不合法

补充约束：

- 主协议不要求统一包装插件 `beforePost` 的错误；插件自定义错误应原样向上传播
- `afterPost` 失败只记录 `AfterPostPluginFailed`，不额外要求统一错误类型

## 9. 数据与事件

### 9.1 必要事件

- `ChatActivate`
- `ChatDeactivate`
- `MetaSet`
- `DelegateGroupIdSet`
- `BeforePostPluginSet`
- `AfterPostPluginSet`
- `MessagePost`
- `AfterPostPluginFailed`
- `DefaultSenderGroupIdSet`
- `DefaultSenderGroupIdCleared`

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

event DelegateGroupIdSet(
    uint256 indexed groupId,
    address indexed owner,
    uint256 indexed delegateGroupId,
    uint256 configVersion,
    uint256 prevDelegateGroupId
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
    uint256 round,
    uint256 messageIndex
);

event AfterPostPluginFailed(
    uint256 indexed chatGroupId,
    uint256 indexed messageIndex,
    address indexed pluginAddress,
    uint256 round,
    bytes errorData
);

event DefaultSenderGroupIdSet(
    address indexed account,
    uint256 indexed senderGroupId
);

event DefaultSenderGroupIdCleared(
    address indexed account,
    uint256 indexed prevSenderGroupId
);
```

说明：

- 任一成功的配置写交易若使 `configVersion` 递增，则该交易内所有配置差异事件都必须携带同一个新 `configVersion`
- `activateChat` 成功时，除 `ChatActivate` 外，还必须为实际发生变化的 `meta`、`delegateGroupId`、`beforePostPlugin`、`afterPostPlugin` 发出对应差异事件
- `deactivateChat` 成功时，只发出 `ChatDeactivate`
- `activateChat` 导致某个旧 `meta` key 被移除时，该移除必须视为一次删除，并发出 `MetaSet(..., value = bytes(\"\"), prevValue = oldValue)`
- `setMetaBatch` 发出的多条 `MetaSet` 事件顺序，必须与输入数组顺序一致
- `activateChat` 中，对旧 live `meta` 被移除的 `key` 发出的删除型 `MetaSet` 事件，必须按旧 live key 顺序发出
- `activateChat` 中，对显式传入 `metaKeys/metaValues` 发出的新增 / 更新型 `MetaSet` 事件，必须与输入数组顺序一致
- `activateChat` 中，对值未变化的保留 `key` 不发 `MetaSet`
- `ChatActivate` 应在同交易内所有配置差异事件之后发出，作为该次开启的汇总事件
- `ChatActivate` / `ChatDeactivate` 不带 `operator`
- 原因：只有 `owner` 可调用，`operator == owner`
- `ChatActivate` / `ChatDeactivate` 不带 `prevActive`
- 原因：事件名本身已表达状态切换动作
- `DelegateGroupIdSet.prevDelegateGroupId` 语义固定为“本次修改前的有效 delegateGroupId”
- 因此它不一定等于修改前存储槽里的原始 `delegateGroupId` 配置值
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
- 必须支持按 `chatGroupId + senderGroupId` 查询该发送身份在该群的消息分页
- 必须支持按 `chatGroupId + senderGroupId` 查询该发送身份在该群的消息索引分页
- 必须支持按 `chatGroupId` 查询该群已发言 `senderGroupId` 列表分页
- 必须支持不传 `round` 查询 `chatGroupId` 下全量消息分页
- 前端消息同步要求：
- 只把 `MessagePost` 当作“发现新消息”的信号
- 正文内容始终以 `messages(...)` / `messagesByRound(...)` 的 `view` 结果为准
- 本地应维护每个 `chatGroupId` 的最新 `messageIndex` 游标
- 收到 `MessagePost` 后：
- 若 `messageIndex == latestMessageIndex + 1`，应使用 `messages(chatGroupId, messageIndex, 1, false)` 拉取该条消息
- 若 `messageIndex > latestMessageIndex + 1`，说明存在缺口，应按缺口区间补拉
- 前端配置同步要求：
- 只把 `ChatActivate`、`ChatDeactivate`、`MetaSet`、`DelegateGroupIdSet`、`BeforePostPluginSet`、`AfterPostPluginSet` 当作“配置已变更”的信号
- 本地应维护每个 `chatGroupId` 的 `configVersion` 缓存
- 收到任一配置事件后：
- 若事件里的 `configVersion` 大于本地缓存，应直接全量重拉当前配置
- 配置全量重拉应至少覆盖：`chatInfo`、`metaEntries`、`delegateGroupIdOf`、`beforePostPlugin`、`afterPostPlugin`
- owner 同步要求：
- `owner` 不属于 `configVersion` 覆盖范围
- 前端若关心当前管理权限，必须以 `chatInfo(groupId).owner`、`GroupNFT.ownerOf(groupId)` 或 `GroupNFT` 的 `Transfer` 事件为准
- delegateGroupId 同步要求：
- `delegateGroupIdOf(groupId)` 不属于 `configVersion` 覆盖范围
- 前端在收到 `GroupNFT` 的 `Transfer` 事件后、进入管理页前、以及发起管理交易前，必须重拉 `delegateGroupIdOf(groupId)`
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

- 管理类写接口必须做 `owner` / 有效 `delegateGroupId` 当前 owner / `active` 校验
- `activateChat`、`deactivateChat` 必须只允许 `owner`
- 发消息接口必须做 `owner` / plugin 校验，不得接受 `delegateGroupId` 当前 owner 冒充发言身份
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
- `delegateGroupId` 当前 owner 只能在授权范围内代管，不能发言、不能激活、不能关闭
- NFT 转让后控制权自动变化
- NFT 转回原 owner 后，旧 `delegateGroupId` 自动恢复
- 消息全量上链且不可改写
- 未挂 `beforePost` 时默认允许跨群发言
- `meta` 能被设置、批量设置、删除、读取、分页枚举
- 插件能限制发言但不能破坏核心不可变性
- `afterPost` 失败不影响主消息落链
- 无成员表也能完成全部公开群聊需求

## 13. 最小测试矩阵

以下矩阵用于实现前定稿。由于协议部署后不可升级，以下用例应视为最小必测集合。

### 13.1 基础夹具

- `T001`：部署 `GroupChat` 时写入 `LOVE20Group`、`originBlocks`、`phaseBlocks`
  关键断言：构造后只读参数正确；`currentRound()` 在 `originBlocks` 前按约定 `revert`
- `T002`：至少准备 4 个 `GroupNFT`
  关键断言：覆盖 chat owner、sender owner、第三方、delegateGroupId owner、跨群发言场景

### 13.2 激活与关闭

- `T010`：未持有 `groupId` 的地址调用 `activateChat`
  关键断言：`revert`
- `T011`：owner 首次 `activateChat`
  关键断言：`active=true`；`configVersion=1`；`firstActivated*` 正确写入；差异事件与 `ChatActivate` 顺序正确
- `T012`：已激活 chat 再次 `activateChat`
  关键断言：`revert`
- `T013`：owner `deactivateChat`
  关键断言：`active=false`；`configVersion` 递增 1；`meta`、`delegateGroupId`、插件槽位不被清空
- `T014`：已关闭 chat 再次 `deactivateChat`
  关键断言：`revert`
- `T015`：关闭后重新 `activateChat`
  关键断言：`firstActivated*` 不变；live 配置按入参原子覆盖；历史消息保持可读

### 13.3 Meta 与 configVersion

- `T020`：`setMeta` 新增 key
  关键断言：当前值更新；`configVersion` 递增；`MetaSet.prevValue=bytes("")`
- `T021`：`setMeta` 更新已有 key
  关键断言：位置不变；`MetaSet.prevValue` 为旧值
- `T022`：`setMeta` 删除已有 key
  关键断言：`metaValue` 变空；`metaEntries` 不再包含该 key；`configVersion` 递增
- `T023`：删除不存在 key
  关键断言：`revert`
- `T024`：写入空 key
  关键断言：`revert`
- `T025`：`setMeta` 写入相同值
  关键断言：`revert`
- `T026`：`setMetaBatch` 含重复 key
  关键断言：整笔 `revert`；无部分写入；无事件
- `T027`：`setMetaBatch` 同时改多个 key
  关键断言：`configVersion` 仅递增 1；多条 `MetaSet` 带同一新版本号；事件顺序与输入一致
- `T028`：重新 `activateChat` 全量覆盖 `meta`
  关键断言：未传入 key 视为删除；保留 key 的相对顺序不变；新 key 追加到尾部；删除型 `MetaSet` 先于新增/更新型 `MetaSet`

### 13.4 DelegateGroupId 与 NFT 转让

- `T030`：owner 设置 `delegateGroupId`
  关键断言：`delegateGroupIdOf(groupId)` 正确返回；`configVersion` 递增
- `T031`：`delegateGroupId` 设为 `groupId` 自己
  关键断言：`revert`
- `T032`：`setDelegateGroupId` 设为当前存储态相同值
  关键断言：`revert`
- `T033`：`setDelegateGroupId(groupId, 0)`
  关键断言：`delegateGroupId` 与 snapshot 同时清空
- `T034`：NFT 转给新 owner
  关键断言：旧 `delegateGroupId` 立即失效；`delegateGroupIdOf(groupId)=0`；`configVersion` 不变
- `T035`：NFT 转回原 owner
  关键断言：旧 `delegateGroupId` 自动恢复；主协议与插件权限同步恢复
- `T036`：前 owner 或失效 `delegateGroupId` owner 继续管理
  关键断言：所有管理写接口均 `revert`

### 13.5 发消息与身份校验

- `T040`：owner 使用自己持有的 `senderGroupId` 发消息
  关键断言：成功落链；`messageIndex` 自增；消息内容与 `senderAddress` 正确
- `T041`：`senderGroupId != chatGroupId` 的跨群发言
  关键断言：在未挂 `beforePost` 插件时默认允许
- `T042`：非 `senderGroupId` owner 冒用身份发言
  关键断言：`revert`
- `T043`：`delegateGroupId` 当前 owner 尝试代替 `senderGroupId` owner 发言
  关键断言：`revert`
- `T044`：关闭态发消息
  关键断言：`revert`
- `T045`：空消息
  关键断言：`revert`
- `T046`：超过 `16384` bytes 的消息
  关键断言：`revert`
- `T047`：`originBlocks` 前发消息
  关键断言：因 `currentRound()` 不可用而 `revert`
- `T048`：消息携带 `mentions`
  关键断言：消息正文、`mentions`、按提及身份的消息分页与索引分页一致
- `T049`：重复 `mentions` 与 `mentionAll` 索引
  关键断言：重复 `mentionedGroupId` 必须 `revert`；`mentionAll=true` 的消息可被独立分页查询
- `T084`：单条消息读取
  关键断言：`message(chatGroupId, messageIndex)` 直接返回完整消息；越界时 `revert`
- `T085`：消息引用
  关键断言：`quotedMessageIndex` 正确存储；不存在或越界引用必须 `revert`
- `T086`：`mentions` 超上限
  关键断言：`mentions.length > 32` 必须 `revert`
- `T087`：默认发言身份发消息
  关键断言：设置默认身份后可通过 `postByDefaultSender(...)` 成功发消息
- `T088`：默认发言身份失效与恢复
  关键断言：NFT 转出后 `defaultSenderGroupIdOf=0`；转回后自动恢复
- `T089`：默认发言身份清理
  关键断言：即使默认身份已失效，只要原始存储存在，`clearDefaultSenderGroupId()` 仍可清理
- `T090`：默认发言身份 no-op
  关键断言：未存储时清理必须 `revert`；重复设置相同原始存储值必须 `revert`

### 13.6 Round 与分页

- `T050`：同一群跨多个 round 发消息
  关键断言：`round` 计算正确；`roundInfo` 的 `[startIndex,endIndex)` 正确
- `T051`：无消息 round 查询
  关键断言：`messagesByRoundCount=0`；`roundInfo` 返回零值结构，不 `revert`
- `T052`：`messages(...)` 正序/倒序分页
  关键断言：顺序正确；`offset` 以最终返回顺序为基准
- `T053`：`messagesByRound(...)` 正序/倒序分页
  关键断言：仅返回该 round 内消息；顺序正确
- `T054`：`rounds(...)` 正序/倒序分页
  关键断言：仅包含有消息 round；顺序正确
- `T055`：`limit == 0` 与分页越界
  关键断言：`messages`、`messagesByRound`、`rounds` 均返回空数组，不 `revert`

### 13.7 按 sender 查询与 sender 列表

- `T060`：同一群内多个 `senderGroupId` 交错发言
  关键断言：`messagesBySender(...)` 仅返回命中消息，且顺序按命中消息的 `messageIndex`
- `T061`：`messagesBySenderCount` 与 `messagesBySender`
  关键断言：count 与分页总量一致
- `T062`：`messageIndexesBySender` 与 `messagesBySender`
  关键断言：两者命中集合一致、顺序一致、`messageIndex` 一一对应
- `T063`：某 `senderGroupId` 在该群无消息
  关键断言：`messagesBySenderCount=0`；`messagesBySender=[]`；`messageIndexesBySender=[]`
- `T064`：传入当前不存在的 `senderGroupId`
  关键断言：相关只读接口返回 `0` 或空数组，不额外 `revert`
- `T065`：`senderGroupIds` 首次发言入列
  关键断言：首次发言的 `senderGroupId` 进入列表
- `T066`：同一 `senderGroupId` 再次发言
  关键断言：`senderGroupIds` 中不重复出现，且位置不改变
- `T067`：`senderGroupIds` 正序/倒序分页
  关键断言：顺序基于首次发言进入列表的顺序；`offset` 以最终返回顺序为基准
- `T068`：`senderGroupIdsCount`、`senderGroupIds(limit=0)`、越界分页
  关键断言：空列表时 count 为 `0`；列表接口返回空数组，不 `revert`

### 13.8 插件与重入语义

- `T070`：未挂插件时 `post`
  关键断言：默认放行
- `T071`：`beforePost` 明确拒绝
  关键断言：整笔 `revert`；不落消息；不发 `MessagePost`；不占用 `messageIndex`
- `T072`：`afterPost` 失败
  关键断言：主消息已落链；`MessagePost` 先发；随后发 `AfterPostPluginFailed`
- `T073`：插件地址为 EOA 或无代码地址
  关键断言：`activateChat`、`setBeforePostPlugin`、`setAfterPostPlugin` 均 `revert`
- `T074`：关闭态下插件内部配置写
  关键断言：主协议配置写仍禁止；插件内部配置写可按插件规则成功
- `T075`：插件尝试重入 `post`
  关键断言：主协议 `nonReentrant` 生效
- `T076`：`afterPost` 尝试修改主协议状态
  关键断言：主消息已落链；主协议状态不被插件篡改
- `T077`：`beforePost` 接收 `mentions` / `mentionAll`
  关键断言：插件收到的上下文与实际发消息入参一致
- `T078`：`beforePost` 判断 `mentionAll`
  关键断言：是否允许 `mentionAll` 由插件决定；主协议不额外拦截
- `T079`：`beforePost` / `afterPost` 接收引用与结果上下文
  关键断言：插件收到的 `quotedMessageIndex`、`messageIndex`、`blockNumber`、`timestamp` 与真实落链结果一致

### 13.9 事件与版本一致性

- `T080`：单次配置写仅改一个项
  关键断言：对应差异事件中的 `configVersion` 与 `chatInfo.configVersion` 一致
- `T081`：单次配置写同时改多个项
  关键断言：`configVersion` 只递增 1；所有差异事件带同一新版本号
- `T082`：`ChatActivate` 事件排序
  关键断言：所有差异事件先发，`ChatActivate` 最后发
- `T083`：`MessagePost` 与正文读取
  关键断言：事件仅作发现信号；正文需通过 `messages(...)` 或 `message(...)` 读取并与落链状态一致

### 13.10 建议测试组织

- 单元测试优先覆盖：权限、零值规则、分页、`configVersion`、事件顺序
- 集成测试优先覆盖：NFT 转让、`delegateGroupId` 恢复、跨 round 发消息、插件 hook、关闭态插件配置写
- 所有新增行为都应先写失败测试，再写实现
