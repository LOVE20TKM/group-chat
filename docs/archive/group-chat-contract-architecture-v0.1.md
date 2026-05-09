# 群聊合约架构设计

- 模块：Group Chat 合约架构
- 状态：讨论稿
- 依据：[群聊类型与发言策略需求文档](./group-chat-type-policy-requirements-v0.1.md)

## 1. 总体原则

主协议保持极薄，但把四类稳定扩展点提升为一等配置：

```text
GroupChat
  -> scopeSource
  -> denySource
  -> beforePostPlugin
  -> afterPostPlugin
```

发送链路：

```text
GroupChat 硬校验
  -> scopeSource.canPost(...)
  -> denySource.isDenied(...)
  -> beforePostPlugin.beforePost(...)
  -> 写消息
  -> afterPostPlugin.afterPost(...)
```

空地址语义：

```text
scopeSource == address(0): 默认开放发言
denySource == address(0): 无黑名单
beforePostPlugin == address(0): 无额外拦截
afterPostPlugin == address(0): 无消息后观察
```

## 2. 基础接口

### 2.1 ScopeSource

```solidity
interface IPostScopeSource {
    function canPost(
        uint256 groupId,
        uint256 senderGroupId,
        address senderAddress
    ) external view returns (bool);
}
```

`scopeSource` 只回答“这个发送身份是否落在该群允许发言的范围内”。

典型 scope：

- 持币 / 有治理票 / 参与行动
- 最近 `X` 轮给某行动投过票
- 链群行动参与者

### 2.2 黑名单源

```solidity
interface IPostDenySource {
    function isDenied(
        uint256 groupId,
        uint256 senderGroupId,
        address senderAddress
    ) external view returns (bool);
}
```

`denySource` 内部可以维护或查询：

- 地址黑名单
- `senderGroupId` 黑名单
- 地址豁免名单
- `senderGroupId` 豁免名单
- 管理员配置
- 治理投票结果

`exemptList` 不单独成为主协议槽位。它是 `denySource` 的内部语义：

```text
if exempt: return false
if denied: return true
return false
```

### 2.3 发言前额外策略

```solidity
interface IBeforePostPlugin {
    function beforePost(
        uint256 groupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external;
}
```

`beforePostPlugin` 不处理基础资格和黑名单，适合承载：

- `mentionAll` 权限
- 发言频率限制
- 内容格式限制
- 引用规则
- 其他非标准拦截

### 2.4 黑名单投票权重源

```solidity
interface IDenyVoteWeightSource {
    function denyVoteWeightOf(
        uint256 groupId,
        address voter
    ) external view returns (uint256);
}
```

票权源必须由具体群类型定义。`GovVotedDenySource` 只负责投票记录、聚合和黑名单判断，不关心票权来自代币治理票、行动轮投票数，还是其他治理权重。

### 2.5 主协议聚合读接口

前端不应为了展示发言按钮分别拼 `scopeSource`、`denySource`、owner 校验和 active 状态。主协议提供聚合预检查：

```solidity
function canPost(
    uint256 groupId,
    uint256 senderGroupId,
    address senderAddress
) external view returns (bool);
```

语义：

- `groupId` 未激活，返回 `false`
- `senderGroupId` 不存在，返回 `false`
- `senderAddress != GroupNFT.ownerOf(senderGroupId)`，返回 `false`
- `scopeSource.canPost(...) == false`，返回 `false`
- `denySource.isDenied(...) == true`，返回 `false`
- 否则返回 `true`

`GroupChat.canPost(...)` 不检查具体消息内容，不调用 `beforePostPlugin`，也不承诺某条具体 `post(...)` 一定成功。最终发送仍以 `post(...)` 为准。

需要展示失败原因时，前端使用：

```solidity
function canPostStatus(
    uint256 groupId,
    uint256 senderGroupId,
    address senderAddress
) external view returns (bool allowed, bytes4 reasonCode);
```

`reasonCode` 固定对齐主协议自定义错误 selector：

```text
0x00000000                         OK
ChatNotActive.selector             chat 未激活
GroupNotExist.selector             groupId 或 senderGroupId 不存在
SenderNotGroupOwner.selector       senderAddress 不是 senderGroupId 当前 owner
ScopeRejected.selector             scopeSource 判定无资格
DenyRejected.selector              denySource 判定被拒绝
ScopeSourceFailed.selector         scopeSource 调用失败
DenySourceFailed.selector          denySource 调用失败
```

`canPost(...)` 等价于 `canPostStatus(...).allowed`。

配置槽位也提供一次性读取：

```solidity
function ruleSlots(uint256 groupId)
    external
    view
    returns (
        address scopeSource,
        address denySource,
        address beforePostPlugin,
        address afterPostPlugin
    );
```

`ruleSlots(...)` 只是聚合读接口。

去中心化群聊的不可变性由 Manager 保证：Manager 持有群聊 NFT，激活后不暴露任何会关闭群聊、重配规则槽位或修改发言资格参数的方法。

### 2.6 状态版本与前端解析

主协议不要求 source / plugin 自报统一类型，也不依赖 `moduleKind()` / `moduleVersion()` 这类函数。

原因：

- 任意合约都可以伪造自报类型
- 去中心化扩展无法保证全局类型不重复
- 类型解析是前端信任问题，不是主协议共识问题

可信解析不上链，由前端自己决定是否维护可信解析表：

```text
chainId + source/plugin address
  -> 可信 adapter
  -> ABI
  -> 展示名称
  -> 专用读取接口
```

未知地址只按通用槽位地址展示；最多调用标准 `canPost(...)` / `isDenied(...)`，不做专用解析。

官方或前端信任的 source / denySource / plugin 建议实现：

```solidity
interface IRuleStateVersion {
    function stateVersion(uint256 groupId) external view returns (uint256);

    event StateVersionChanged(
        uint256 indexed groupId,
        uint256 stateVersion
    );
}
```

版本分工：

```text
GroupChat.configVersion        -> 槽位地址、meta、delegate、active 变化
source.stateVersion            -> source 内部状态变化
denySource.stateVersion        -> denySource 内部状态变化
beforePostPlugin.stateVersion  -> plugin 内部状态变化，如有
```

前端只有在可信 adapter 标记该模块支持 `stateVersion` 时才调用它。

官方可信模块发生内部状态变化时，应发出 `StateVersionChanged`。第三方模块即使也发同名事件，前端也只在该模块地址命中可信解析表时处理。

## 3. 通用发送判定顺序

```text
1. GroupChat 硬校验
2. 若 scopeSource != address(0)，调用 canPost(...)
3. 若 canPost 返回 false，拒绝
4. 若 denySource != address(0)，调用 isDenied(...)
5. 若 isDenied 返回 true，拒绝
6. 若 beforePostPlugin != address(0)，调用 beforePost(...)
7. 写消息
8. 若 afterPostPlugin != address(0)，调用 afterPost(...)
```

职责边界：

- `scopeSource` 决定本来有没有资格发言
- `denySource` 决定本来能发的人是否被禁言
- `beforePostPlugin` 决定其他额外规则
- `afterPostPlugin` 只观察已落链消息，失败不回滚主消息

## 4. 合约族

### 4.1 主协议

```text
GroupChat
```

职责：

- chat 生命周期
- owner / delegate 管理入口
- 配置并调用 `scopeSource`
- 配置并调用 `denySource`
- 配置并调用 `beforePostPlugin`
- 配置并调用 `afterPostPlugin`
- 消息写入与索引

不负责：

- 群类型识别
- source / plugin 类型声明
- 成员资格状态
- 黑名单状态
- 投票聚合
- 额外内容策略

### 4.2 Manager

去中心化群聊可由 Manager 持有群聊 NFT。

Manager 职责：

- 持有或创建 `groupId`
- 绑定 token / action scope
- 通过 `activate(...)` 创建并激活对应类型群聊
- 激活群聊时一次性写入规则槽位
- 激活群聊时 `delegateGroupId = 0`
- 实现 `IPostScopeSource`
- 对治理投票黑名单场景，实现 `IDenyVoteWeightSource`

四种代币/行动去中心化群聊分别对应四个 Manager。激活函数统一命名为 `activate(...)`，但每个 Manager 的入参按自身类型定义，不走通用参数模板。

Manager 不继承黑名单。Manager 激活群聊后，token / action scope、最近 `X` 轮、规则槽位与其他发言资格参数都不可再改。

Manager 约束：

- 激活后不可关闭群聊
- 激活后不可重配 `scopeSource`、`denySource`、`beforePostPlugin`、`afterPostPlugin`
- 激活后不可修改 token / action scope、最近 `X` 轮、发言资格参数
- 不得暴露通用 `call` / `delegatecall` / `execute` 后门
- 不可升级

### 4.3 DenySource

DenySource 是实际挂到 `GroupChat.denySource` 的合约。

职责：

- 查询或维护 `denyList`
- 查询或维护 `exemptList`
- 在 `isDenied(...)` 中返回是否拒绝发言

治理投票型黑名单统一使用 `GovVotedDenySource`。这里的 `Gov` 表示“由投票治理产生黑名单”，不限定票权必须是代币治理票。不同群聊的差异只来自对应 `IDenyVoteWeightSource`。

`GovVotedDenySource` 只允许配置每个 `groupId` 的投票权重源：

```text
voteWeightSourceOf(groupId) -> IDenyVoteWeightSource
```

四种代币/行动去中心化群聊中：

```text
voteWeightSource = 对应 Manager
```

即由 Manager 同时提供 `denyVoteWeightOf(...)`。阈值、投票期、是否支持反对票 / 撤票 / 复议等其他规则，全部在 `GovVotedDenySource` 构造时确定，部署后不按群重配。

### 4.4 BeforePostPlugin

BeforePostPlugin 是实际挂到 `GroupChat.beforePostPlugin` 的合约。

职责：

- 只处理资格和黑名单之外的额外拦截
- 通过 `revert` 拒绝发言

### 4.5 AfterPostPlugin

AfterPostPlugin 是实际挂到 `GroupChat.afterPostPlugin` 的合约。

职责：

- 只观察已落链消息
- 不得影响主消息成功落链
- 失败只触发 `AfterPostPluginFailed`

主协议不强制设置 gas cap。原因：

- 去中心化群聊激活前应自行测试插件，Manager 激活后不能上线替换
- 中心化群聊可以替换有问题的插件
- gas cap 属于具体部署和运维风险，不应成为主协议复杂性来源

## 5. 五种去中心化群聊

### 5.1 代币社区群聊

```text
TokenGroupChatManager
  - ownerOf(groupId)
  - activate(groupId, token)
  - canPost = 持币 OR 参与过行动 OR 有治理票
  - denyVoteWeightOf = 地址持有的治理票

GroupChat.scopeSource = TokenGroupChatManager
GroupChat.denySource = GovVotedDenySource
GovVotedDenySource.voteWeightSource = TokenGroupChatManager
GroupChat.beforePostPlugin = 可选
```

### 5.2 代币治理者群聊

```text
TokenGovGroupChatManager
  - ownerOf(groupId)
  - activate(groupId, token)
  - canPost = 有代币治理票
  - denyVoteWeightOf = 地址持有的治理票

GroupChat.scopeSource = TokenGovGroupChatManager
GroupChat.denySource = GovVotedDenySource
GovVotedDenySource.voteWeightSource = TokenGovGroupChatManager
GroupChat.beforePostPlugin = 可选
```

### 5.3 代币行动治理者群聊

```text
TokenActionGovGroupChatManager
  - ownerOf(groupId)
  - activate(groupId, token, actionId, recentRounds)
  - canPost = 最近 X 轮给该行动投过票
  - denyVoteWeightOf = 地址当前行动轮的投票数

GroupChat.scopeSource = TokenActionGovGroupChatManager
GroupChat.denySource = GovVotedDenySource
GovVotedDenySource.voteWeightSource = TokenActionGovGroupChatManager
GroupChat.beforePostPlugin = 可选
```

### 5.4 代币行动群聊

```text
TokenActionGroupChatManager
  - ownerOf(groupId)
  - activate(groupId, token, actionId, recentRounds)
  - canPost = 最近 X 轮给该行动投过票 OR 参与这个行动
  - denyVoteWeightOf = 地址当前行动轮的投票数

GroupChat.scopeSource = TokenActionGroupChatManager
GroupChat.denySource = GovVotedDenySource
GovVotedDenySource.voteWeightSource = TokenActionGroupChatManager
GroupChat.beforePostPlugin = 可选
```

四类代币/行动去中心化群聊共用 `GovVotedDenySource`。差异只在：

- `scopeSource.canPost(...)`
- `IDenyVoteWeightSource.denyVoteWeightOf(...)`
- Manager `activate(...)` 的入参

### 5.5 链群群聊

```text
GroupChat.scopeSource = 链群行动参与资格源
GroupChat.denySource = AdminDenySource
GroupChat.beforePostPlugin = 可选

AdminDenySource
  - denyList = owner / delegate / admin 管
  - exemptList = owner / delegate 管
```

链群群聊不用治理投票黑名单。它本质是链群服务者中心管理的群聊，黑名单由服务者侧管理。链群行动参与资格源可以是链群扩展合约、适配器合约，或任何实现 `IPostScopeSource` 的合约。

## 6. 中心化群聊

中心化群聊不使用 Manager 托管 NFT。

```text
Open:
  GroupChat.scopeSource = address(0)
  GroupChat.denySource = AdminDenySource
  GroupChat.beforePostPlugin = 可选
```

如后续需要成员制群聊，应新增独立 `scopeSource`，不要把成员资格混入 `AdminDenySource` 的黑名单语义。

## 7. AdminDenySource 权限模型

角色：

```text
owner:
  GroupNFT.ownerOf(groupId)

delegate:
  GroupChat.delegateGroupIdOf(groupId) 的当前 owner

admin:
  denySource 内配置的 adminGroupIds 的当前 owner
```

权限：

```text
owner / delegate:
  - 管理 adminGroupIds
  - 管理 denyList
  - 管理 exemptList

admin:
  - 管理 denyList
```

不缓存地址权限，必须实时读取 NFT owner。

## 8. 共享组件

推荐只抽象无权限语义的底层能力：

```text
DualSubjectListStore
  - address list
  - senderGroupId list
  - add/remove/check/page

VotedDenyStore
  - address target votes
  - senderGroupId target votes
  - support/against/settledWeight

OwnerDelegateAdminAuth
  - 实时读取 owner / delegate / adminGroupId owner
```

不要抽象：

```text
AdminDenySource -> GovVotedDenySource
```

原因：管理员直接拉黑和治理投票拉黑是不同权限模型。

## 9. 最终建议清单

```text
Core:
  - GroupChat

Managers:
  - TokenGroupChatManager
  - TokenGovGroupChatManager
  - TokenActionGovGroupChatManager
  - TokenActionGroupChatManager

ScopeSources:
  - 链群行动参与资格源

DenySources:
  - GovVotedDenySource
  - AdminDenySource

BeforePostPlugins:
  - 可选扩展，按需实现

Shared:
  - DualSubjectListStore
  - VotedDenyStore
  - OwnerDelegateAdminAuth
```
