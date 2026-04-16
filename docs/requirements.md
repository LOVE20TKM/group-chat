# Group Chat 需求文档

- 项目：LOVE20 Group Chat
- 状态：草案
- 目标：基于 `GroupNFT` 的完全链上公开群聊协议
- 版本：v0.1

## 1. 背景

LOVE20 现有协议里，`GroupNFT` 已经可以作为链上的身份与所有权凭证。群聊协议应直接复用这层身份，不再引入中心化账号系统，也不做成员表、私聊门禁或链下托管。

本协议的核心判断是：

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

消息对所有人公开可读，不做读权限隔离。

### 3.3 简单优先

协议只保留必要状态，不在协议层做复杂的权限树、子频道树或治理流程。

### 3.4 扩展外置

扩展能力通过 `meta` 和 `plugin` 完成，不污染协议的最小模型。

### 3.5 写入不可逆

消息只增不改，元信息可以更新，但历史版本必须可追踪。

## 4. 术语

| 术语 | 含义 |
| --- | --- |
| GroupNFT | LOVE20 链群 NFT，作为链上身份凭证 |
| Chat | 与某个 `GroupNFT` 绑定的公开群聊 |
| groupId | 群聊唯一标识，直接使用 `GroupNFT` 编号 |
| owner | 当前持有该 `GroupNFT` 的地址，实时变化 |
| delegate | 由 owner 设置、可代行管理与发言的地址 |
| meta | 群聊的 KV 元信息 |
| plugin | 消息前后钩子合约 |
| round | 群聊消息轮次，默认直接对齐 LOVE20 `Join.currentRound()` |

## 5. 协议范围

### 5.1 核心范围

- 激活群聊
- 查询群聊
- 设置 / 更新元信息
- 设置 / 清空代理
- 设置 / 清空插件
- 发消息
- 查询消息
- 关闭 / 恢复群聊
- NFT 转移后控制权自然转移

### 5.2 扩展范围

- 代币社群群聊
- 行动社群群聊
- 规则型发言控制
- 外部 meta 路由

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
- `owner`，实时读取当前 `ownerOf(groupId)`
- `activatedOwner`，首次激活时的 `owner` 快照
- `active`
- `metaVersion`
- `pluginVersion`
- `activatedBlockNumber`

### 6.2 Message

每条消息至少包含：

- `groupId`，直接等于 `GroupNFT` 编号
- `round`
- `messageIndex`，群内全局消息序号
- `sender`
- `content`
- `timestamp`
- `blockNumber`

实际存储模型：

- 每个 `groupId` 下只有一条追加式消息列表
- `round` 只记录这条列表里哪一段属于该轮
- `messageIndex` 以整个群的消息列表为准，不按 `round` 重置

### 6.3 RoundSpan

每个轮次至少包含：

- `groupId`
- `round`
- `startIndex`
- `endIndex`

### 6.4 MetaEntry

每个元信息条目至少包含：

- `key`
- `value`
- `updatedBy`
- `updatedBlockNumber`

### 6.5 PluginConfig

每个插件配置至少包含：

- `hookType`
- `pluginAddress`
- `enabled`
- `configData`

## 7. 功能需求

### 7.1 1 NFT = 1 Chat

- 每个 `GroupNFT` 只对应一个主群聊。
- 群聊身份由 NFT 持有关系决定。
- 群聊不再需要独立的成员体系。
- 群聊首次激活时，记录 `activatedOwner = ownerOf(groupId)`。
- `activatedOwner` 不随 NFT 转移变化。
- 群聊激活后，应与该 NFT 的身份绑定直到 NFT 转移。

验收条件：

- 同一个 `groupId` 只能激活一次主群聊。
- NFT 转移后，新 owner 立即获得群聊控制权。

### 7.2 群聊激活

- NFT 当前持有者可激活群聊。
- 激活时可同时设置基础 `meta`、插件配置。
- 激活后，群聊状态必须可查询。

建议接口：

- `activateChat(groupId, metaKeys, metaValues, plugins)`
- `chatOf(groupId)`

验收条件：

- 未持有 NFT 的地址不能激活。
- 重复激活必须失败。

### 7.3 主键

- `groupId` 直接等于 `GroupNFT` 的 `tokenId`。
- 协议内所有 `chat`、消息、`meta`、插件状态都挂在 `groupId` 下。
- 不额外引入 `chatId`、`identifier` 等同义字段。

### 7.4 元信息 KV

- 每个群聊必须支持 KV 元信息。
- `meta` 必须能单键读取。
- `meta` 必须能分页枚举。
- `meta` 更新必须保留历史可追踪性。
- `meta` 的内容应允许承载字符串、地址、JSON 编码文本、其他协议引用。

建议命名空间：

- `name`
- `description`
- `avatar`
- `link.main`
- `link.token.<tokenSymbol>`
- `link.action.<tokenSymbol>.<actionId>`
- `plugin.beforePost.<i>`
- `plugin.afterPost.<i>`

验收条件：

- 可通过 meta 指向行动群、代币群。
- 这里用 Launch 发射时的 `symbol`，不再用 token address。
- 协议不需要理解这些引用的业务语义。

### 7.5 群聊状态

- 群聊必须有 `active` 状态。
- `active = false` 时禁止发消息和修改配置。
- 关闭状态不影响历史消息读取。
- 恢复后继续使用同一聊天身份和历史记录。

建议接口：

- `setActive(groupId, bool)`
- `isActive(groupId)`

验收条件：

- 关闭不会清空任何历史。
- 恢复不改变 groupId。

### 7.6 代理机制

- NFT 当前持有者可设置代理。
- 代理可代行群聊管理、发言权限。
- 代理必须与当前 owner 绑定。
- NFT 转移后，旧代理必须立即失效。
- 新 owner 必须重新设置代理。

要求：

- 不允许代理地址等于 owner 自己的强制重复设置。
- 代理状态必须可查询。
- 代理配置必须可清空。

建议接口：

- `setDelegate(groupId, delegate)`
- `delegateOf(groupId)`

验收条件：

- 旧 owner 的代理不应在 NFT 转回后自动恢复。
- 代理不能绕过 `active` 状态。

### 7.7 发消息

- 发消息时必须指定一个持有的 `groupId` 作为身份。
- 发送者必须是该 NFT 当前 owner 或其 delegate，或被插件显式允许。
- 消息内容必须完整上链。
- 消息只能新增，不能编辑或删除。
- 消息必须包含发送者、groupId、时间、区块号、轮次、序号等上下文。

建议接口：

- `post(groupId, content)`

验收条件：

- 不持有该 NFT 的地址不能冒用身份发言。
- 每条消息必须可追溯到具体 groupId。

### 7.8 轮次与分页

- 群聊必须按轮次组织消息。
- `round` 默认直接复用 LOVE20 `Join.currentRound()`。
- `currentRound()` 直接复用 `Join.currentRound()`，不传 `groupId`。
- 这样消息分桶、行动参与、验证窗口天然对齐，最适合 LOVE20 这类行动型社群。
- 实际存储是 `groupId` 下单一消息列表。
- `round` 只标记这条列表中的区间，形式是 `[startIndex, endIndex)`。
- 协议不再单独造一套消息桶。
- 查询接口必须同时支持带 `round` 和不带 `round` 两种模式。
- 不带 `round` 时，按 `groupId` 对全量消息分页，顺序按 `messageIndex`。
- 每个轮次内部必须支持分页查询。
- 轮次列表也应支持分页查询。

建议查询：

- `currentRound()`
- `messageCount(groupId)`
- `messageCount(groupId, round)`
- `getMessages(groupId, offset, limit, reverse)`
- `getMessages(groupId, round, offset, limit, reverse)`
- `getRounds(groupId, offset, limit, reverse)`

验收条件：

- 任意轮次都能分页读出完整消息。
- 不传 `round` 也能分页读出该群全量消息。
- 客户端可用 `messageCount` / 最新 `messageIndex` 判断是否有新消息。
- 查询无需依赖中心化索引才可成立。

### 7.9 插件系统

- 群聊必须支持插件合约。
- 插件按场景挂载，至少支持发送前和发送后钩子。
- `beforePost` 可拒绝消息发送。
- `afterPost` 只能观察结果，不能修改已上链消息。
- 插件配置由 NFT owner 或 delegate 管理。
- 插件系统不得引入协议级管理员。

建议 hook：

- `beforeActivateChat`
- `beforePost`
- `afterPost`
- `beforeSetMeta`
- `beforeSetActive`

验收条件：

- 可以通过插件限制哪些人能发消息。
- 可以通过插件做审核、同步、镜像等扩展。

### 7.10 NFT 转让语义

- NFT 转让等同于群聊控制权转移。
- 新 owner 接管群聊 meta、状态、插件与发言控制权。
- 历史消息、历史 meta 版本、历史事件不变。
- 转让不得修改消息归属。

建议实现：

- 转移事件触发后，群聊 owner 读值随 NFT 变化即时更新。
- delegate 配置按 ownership epoch 失效。

验收条件：

- 转让前后群聊地址不变，控制人变化。
- 历史内容保持完整。

## 8. 推荐最小接口

以下接口是建议，不是最终 ABI，但实现应覆盖等价能力：

- `activateChat`
- `setMeta`
- `getMeta`
- `listMeta`
- `setActive`
- `setDelegate`
- `setPlugins`
- `post`
- `getMessages`
- `getRounds`
- `messageCount`
- `chatOf`
- `isActive`

## 9. 数据与事件

### 9.1 必要事件

- `ChatActivate`
- `ChatUpdate`
- `MetaSet`
- `DelegateSet`
- `PluginSet`
- `ChatActiveChange`
- `MessagePost`

### 9.2 事件字段要求

每个关键事件至少应携带：

- `groupId`
- `owner`
- `sender`
- `round`
- `index`，群内全局消息序号

### 9.3 索引要求

- 必须支持按 `groupId` 查询 chat。
- 必须支持按 `groupId + round` 查询该轮消息区间。
- 必须支持按 `groupId` 查询消息分页。
- 必须支持不传 `round` 查询全量消息分页。

## 10. 非功能要求

### 10.1 去中心化

- 无升级管理员
- 无后门
- 无中心化审核开关
- 无特权恢复口

### 10.2 安全

- 所有写接口必须做 owner / delegate / plugin 校验
- 插件不能越权修改核心状态
- 代理配置要防止旧权限复活
- 消息内容要有明确长度上限

### 10.3 可扩展

- 协议状态尽量少
- 新功能优先通过 meta 和 plugin 扩展
- 不把子频道、成员表、复杂治理塞进协议

### 10.4 可组合

- 群聊可引用其他群聊
- 群聊可引用 LOVE20 代币或行动信息
- 群聊可作为行动、治理、服务的统一承载层

### 10.5 可维护

- 历史数据必须可分页读取
- 事件必须足够给前端和索引器使用
- 状态必须与事件一致

## 11. 建议的协议边界

### 11.1 协议只做

- 身份
- 控制权
- meta
- 插件
- 消息
- 轮次

### 11.2 协议不做

- 子频道树
- 成员表
- 私聊
- 删除消息
- 投票审批
- 链下同步

## 12. 验收标准

协议可视为完成，需同时满足：

- 任何人都能读取任意 chat 历史消息
- `GroupNFT` owner 能激活并管理对应 chat
- `delegate` 能在授权范围内代管
- NFT 转让后控制权自动变化
- 消息全量上链且不可改写
- `meta` 能挂其他关联群
- 插件能限制发言但不能破坏核心不可变性
- 没有成员表也能完成全部公开群聊需求

## 13. 未决问题

以下问题在实现前需要最终定稿：

- `meta` 采用 `string -> bytes` 还是 `bytes32 -> bytes`
- 消息长度上限取 8KB、16KB 还是 32KB
- `plugin` 是否允许多插件链式执行
