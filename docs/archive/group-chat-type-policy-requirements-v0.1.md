# 群聊类型与发言策略需求文档

- 模块：Group Chat 类型与发言策略
- 状态：讨论稿
- 目标：明确两类群聊、五种去中心化群聊的发言资格、黑名单、豁免名单边界

## 1. 核心前提

- 群聊主协议一旦部署不可变更
- 每个群聊以 `GroupNFT` 为身份与控制权根
- 消息发送身份为 `senderGroupId`
- 实际签名地址为 `senderAddress`
- `senderAddress` 必须是 `senderGroupId` 当前 owner
- 基础发言资格通过 `scopeSource` 承载
- 黑名单与豁免名单通过 `denySource` 承载
- 其他发言前扩展规则通过 `beforePostPlugin` 承载

## 2. 主协议职责

主协议只负责不可变事实和标准扩展点调用：

- 校验 `chatGroupId` 存在
- 校验 chat 已激活
- 校验 `msg.sender == ownerOf(senderGroupId)`
- 校验消息内容、提及、引用消息合法
- 调用 `scopeSource` 判断基础发言资格
- 调用 `denySource` 判断是否被禁言
- 调用 `beforePostPlugin` 执行额外发言前规则
- 写入消息、索引与事件
- 调用 `afterPostPlugin` 执行消息落链后的观察逻辑

主协议不维护：

- 群类型
- 成员表
- 黑名单状态
- 豁免名单状态
- 治理投票
- 行动参与资格
- 管理员集合

## 3. 判断主体

| 主体 | 含义 | 用途 |
| --- | --- | --- |
| `senderGroupId` | 消息展示与链上身份 NFT | 消息作者、身份级黑名单、身份级豁免名单 |
| `senderAddress` | 当前签名地址，且必须持有 `senderGroupId` | 代币余额、治理票、行动参与、地址级黑名单、地址级豁免名单 |

原则：

- 消息身份以 `senderGroupId` 为准
- 资产、投票、行动参与资格通常以 `senderAddress` 为准
- 黑名单和豁免名单都应支持 `senderAddress` 与 `senderGroupId` 两个维度

## 4. 三个标准规则概念

### 4.1 Scope

基础发言资格。

回答：

- 当前 `senderAddress` / `senderGroupId` 是否本来就有资格发言

例如：

- 持币
- 有治理票
- 参与行动
- 最近 `X` 轮投票

实现上，`scopeSource` 是群聊协议的一等配置槽位，由群聊 NFT 当前 owner 或有效代理配置。

### 4.2 Deny

黑名单判断。

回答：

- 当前 `senderAddress` 或 `senderGroupId` 是否应被禁言

实现上，`denySource` 是群聊协议的一等配置槽位。不同群聊可挂不同黑名单源。

### 4.3 Exempt

黑名单豁免。

回答：

- 当前 `senderAddress` 或 `senderGroupId` 是否豁免黑名单

注意：

- `exemptList` 不提供基础发言资格
- `exemptList` 不单独成为主协议槽位
- `exemptList` 是 `denySource` 的内部规则
- 如果没有基础发言资格，即使命中 `exemptList` 也不能发言

统一发送处理顺序：

```text
1. 主协议判断基础发言资格
2. 无基础发言资格，拒绝
3. 主协议判断是否被禁言
4. 命中黑名单且未豁免，拒绝
5. 主协议调用 beforePostPlugin 执行额外规则
6. 写消息
7. 主协议调用 afterPostPlugin 执行消息后观察逻辑
```

## 5. 群聊分类

群聊分为两类：

- 去中心化群聊
- 中心化群聊

中心化群聊不应要求 Manager 托管群聊 NFT。去中心化群聊可以由 Manager 持有群聊 NFT。

去中心化 Manager 原则：

- 去中心化群聊由 Manager 激活，激活时 `delegateGroupId = 0`
- 四种代币/行动去中心化群聊分别对应四个 Manager
- Manager 激活函数统一命名为 `activate(...)`，入参按群聊类型定义，不走通用群类型参数
- Manager 激活后，群聊不可关闭
- Manager 激活后，不可重配 `scopeSource`、`denySource`、`beforePostPlugin`、`afterPostPlugin`
- Manager 激活后，token / action scope、最近 `X` 轮、发言资格参数不可再改
- Manager 不得暴露通用 `call` / `delegatecall` / `execute` 后门，且不可升级
- 中心化群聊不使用 Manager 约束，owner / delegate 可以替换有问题的 source / plugin
- 可信解析不上链，由前端自己决定是否按 `chainId + 合约地址` 维护可信解析表

治理黑名单原则：

- 四种代币/行动去中心化群聊共用 `GovVotedDenySource`
- 票权来自按 `chatGroupId` 配置的 `IDenyVoteWeightSource`
- 默认票权源就是该群聊对应的 Manager
- 阈值、投票期、反对票 / 撤票 / 复议等规则由 `GovVotedDenySource` 构造时确定，部署后不按群重配

## 6. 五种去中心化群聊

### 6.1 代币社区群聊

发言资格：

- 持有该代币的地址
- 或参与过该代币行动的地址
- 或有该代币治理票的地址

黑名单：

- 使用治理投票型 `denySource`
- 投票权重来自 `TokenGroupChatManager`
- 权重语义为地址持有的治理票
- 支持地址维度与 `senderGroupId` 维度目标

豁免名单：

- 无

### 6.2 代币治理者群聊

发言资格：

- 有该代币治理票的地址

黑名单：

- 使用治理投票型 `denySource`
- 投票权重来自 `TokenGovGroupChatManager`
- 权重语义为地址持有的治理票
- 支持地址维度与 `senderGroupId` 维度目标

豁免名单：

- 无

### 6.3 代币行动治理者群聊

发言资格：

- 给某个行动在最近 `X` 轮投过票的地址

黑名单：

- 使用治理投票型 `denySource`
- 投票权重来自 `TokenActionGovGroupChatManager`
- 权重语义为地址当前行动轮的投票数
- 支持地址维度与 `senderGroupId` 维度目标

豁免名单：

- 无

### 6.4 代币行动群聊

发言资格：

- 给某个行动在最近 `X` 轮投过票的地址
- 或参与这个行动的地址

黑名单：

- 使用治理投票型 `denySource`
- 投票权重来自 `TokenActionGroupChatManager`
- 权重语义为地址当前行动轮的投票数
- 支持地址维度与 `senderGroupId` 维度目标

豁免名单：

- 无

### 6.5 链群群聊

发言资格：

- 通过这个链群参与行动的地址
- 不限代币

黑名单：

- 链群服务者中心管理
- 由群聊 NFT 当前持有者、有效代理，或其指定管理员管理
- 支持地址维度与 `senderGroupId` 维度目标

豁免名单：

- 由群聊 NFT 当前持有者或有效代理管理
- 支持地址维度与 `senderGroupId` 维度目标
- 只豁免黑名单，不增加发言资格

## 7. 中心化群聊

中心化群聊边界：

- 群聊 NFT 不托管给 Manager
- 群聊 NFT 当前 owner 直接控制群聊
- 可使用 `delegateGroupId` 代理管理
- 可配置管理员集合
- 可配置黑名单
- 可配置豁免名单
- 当前只定义开放模式

推荐模式：

```text
Open:
  scopeSource = address(0)
  denySource = AdminDenySource
```

如后续需要成员制群聊，应新增独立 `scopeSource`，不要把成员资格放进 `exemptList` 或 `AdminDenySource`。

## 8. 前端与扩展要求

主协议不要求所有 source / plugin 自报统一类型。

原因：

- 任意第三方合约都可以伪造类型
- 去中心化扩展无法保证类型命名全局唯一
- 是否“可信、可解析”应由前端或官方 registry 决定

前端推荐规则：

- 先读取 `GroupChat.ruleSlots(chatGroupId)`
- 使用 `chainId + 合约地址` 组成的可信地址表匹配 `scopeSource`、`denySource`、`beforePostPlugin`
- 命中可信地址时，使用对应专用 ABI 读取展示数据
- 未命中可信地址时，只展示合约地址与通用状态
- 发言按钮可用性优先读取 `GroupChat.canPost(chatGroupId, senderGroupId, senderAddress)`
- 需要展示不能发言的原因时，读取 `GroupChat.canPostStatus(chatGroupId, senderGroupId, senderAddress)`
- `canPost` 只是无内容预检查，真实发送仍以 `post` 结果为准
- `mentionAll`、特殊引用、内容格式限制等具体动作，不应只依赖 `canPost`

可信模块可选实现：

```solidity
function stateVersion(uint256 chatGroupId) external view returns (uint256);

event StateVersionChanged(
    uint256 indexed chatGroupId,
    uint256 stateVersion
);
```

用于前端发现并缓存该模块内部状态。主协议不强制所有模块实现。

## 9. 已定参数与未决参数

- 最近 `X` 轮由对应 Manager 的构造参数或专属激活参数确定，群聊激活后不可改
- 中心化群管理员当前只管理黑名单，不管理基础发言资格
- 链群群聊当前不定义开放模式，发言资格来自链群行动参与
- `GovVotedDenySource` 构造参数：阈值、投票期、反对票 / 撤票 / 复议规则
- `senderGroupId` 维度黑名单的投票权如何从地址票权映射
