# 治理者群聊插件需求文档

- 项目：治理者群聊插件
- 状态：草案
- 类型：`beforePost`
- 目标：让 LOVE20 治理者基于治理票，对地址或 `GroupNFT` 身份进行黑名单治理，结果直接作用于消息发送前拦截。

## 1. 背景

`Group Chat` 核心协议已经支持 `beforePost` 插件，可在消息写入前做权限判断。

部分群聊场景需要：

- 黑名单决策不依赖单点管理员
- 黑名单规则由治理者而非运营者决定
- 发言限制可链上审计、可事件追踪
- 封禁对象既可能是地址，也可能是发言身份对应的 `GroupNFT`

相对“指定管理群直接维护黑名单”的方案，治理版插件更适合治理讨论群、长期公共社群、需要把禁言权交给治理者共识的场景。

## 2. 目标

### 2.1 必须达到

- 插件挂载在单个群聊的 `beforePost` 钩子上
- 初始化时必须指定治理来源的代币社群
- 初始化时可选指定“对某轮某行动投过票的治理者”作为附加过滤条件
- 支持对一个或多个地址或 `GroupNFT groupId` 发起黑名单治理提案
- 计票按 LOVE20 治理票权重，不按人数
- 支持票严格大于半数时，目标立即加入黑名单
- 到截止仍未过半支持时，目标从黑名单中移除，或保持非黑名单状态
- 黑名单中的地址、`GroupNFT groupId` 无法发送消息
- 所有提案、投票、状态变化都能链上验证

### 2.2 不追求

- 文本内容审核
- 关键词过滤
- 已上链消息删除、撤回、编辑
- 中心化管理员手动封禁
- 链下签名投票
- 全局跨群共享黑名单
- 任意外部 NFT 合约作为发言身份

## 3. 术语

| 术语                | 含义                                                                               |
| ------------------- | ---------------------------------------------------------------------------------- |
| chatGroupId         | 被本插件保护的目标群 `groupId`，等于主协议里的 `chatGroupId`                       |
| senderGroupId       | 发消息时使用的身份 `groupId`                                                       |
| governanceCommunity | 作为治理来源的代币社群                                                             |
| actionVoteFilter    | 可选过滤条件，由 `filterVoteRound + filterActionId` 组成，指某轮某行动的投票者集合 |
| governor            | 在指定代币社群中持有有效治理票的地址                                               |
| eligibleGovernor    | 应用可选过滤条件后，本次提案有资格参与的治理者                                     |
| governanceVotes     | LOVE20 治理票权重                                                                  |
| blacklistTarget     | 黑名单目标，类型为地址或 `GroupNFT groupId`                                        |
| blacklistProposal   | “这些目标是否应处于黑名单状态”的治理提案                                           |
| snapshot            | 提案创建时对治理者集合与票权的快照                                                 |

## 4. 核心规则

### 4.1 插件边界

- 本插件只负责 `beforePost` 拦截
- 本插件不修改消息内容
- 本插件不修改群聊 owner、delegate、meta、active 等核心状态
- 本插件实例只对挂载它的 `chatGroupId` 生效，不自动扩散到其他群

### 4.2 黑名单目标

- 目标支持地址
- 目标支持 `GroupNFT groupId`
- `GroupNFT` 目标仅指群聊协议里的发言身份 `groupId`
- 不支持外部 ERC721 合约地址 + tokenId

### 4.3 判断优先级

插件在 `beforePost` 中至少按以下顺序判断：

1. 检查 `senderAddress` 是否在地址黑名单
2. 检查 `senderGroupId` 是否在 NFT 黑名单
3. 任一命中即拒绝发送
4. 两者都未命中则放行

补充语义：

- 插件内 `msg.sender` 是群聊主协议合约，不是真实发言地址
- 地址黑名单判断必须使用 hook 输入中的 `senderAddress`
- 插件必须仅依赖 hook 入参中的 `senderAddress` 与 `senderGroupId`

### 4.4 治理资格来源

- 治理资格基础来源必须是一个代币社群 `governanceCommunity`
- 可额外附加 `actionVoteFilter`
- 若启用过滤条件，则只有“在指定代币社群中、且在指定轮次对指定行动投过非零治理票”的治理者可参与
- 若不启用过滤条件，则该代币社群中的全部治理者都可参与

### 4.5 快照计票

- 每个提案必须在创建时快照治理者集合与治理票权重
- 提案创建后，新增、减少、转移治理票都不影响该提案结果
- 单个治理者对单个提案最多投一次

### 4.6 过半规则

- 支持票严格大于快照总治理票一半，提案立即通过
- 等于一半不算通过
- 到截止仍未严格过半支持，提案拒绝
- 提案通过后，目标立即加入黑名单
- 提案拒绝后，目标立即从黑名单中移除，或保持非黑名单状态

## 5. 对象模型

### 5.1 PluginConfig

每个 `chatGroupId` 至少维护：

- `governanceCommunity`
- `voteDurationBlocks`
- `filterVoteRound`
- `filterActionId`
- `configVersion`

设计要求：

- `governanceCommunity` 必填
- `filterVoteRound + filterActionId` 可选，但必须同时出现
- 配置变更必须可事件追踪

### 5.2 BlacklistState

插件至少维护两类名单：

- `mapping(address => bool) addressBlacklist`
- `mapping(uint256 => bool) groupBlacklist`

并至少可查询：

- `listed`
- `lastProposalId`
- `updatedBlockNumber`

### 5.3 BlacklistProposal

每个提案至少包含：

- `proposalId`
- `chatGroupId`
- `proposer`
- `targets`
- `reason`
- `evidenceURI`
- `snapshotBlockNumber`
- `snapshotTotalGovernanceVotes`
- `deadlineBlock`
- `supportVotes`
- `againstVotes`
- `status`

建议 `status`：

- `Active`
- `Passed`
- `Rejected`

### 5.4 ProposalVoterSnapshot

每个提案至少可查询某治理者的：

- `eligible`
- `snapshotVotes`
- `hasVoted`
- `support`

## 6. 功能需求

### 6.1 初始化配置

- 目标群 `owner` 或 `delegate` 可安装并初始化该插件
- 初始化时必须设置 `governanceCommunity`
- 初始化时可选设置 `filterVoteRound + filterActionId`
- 初始化时必须设置投票时长
- 若配置不完整，插件不得进入可用状态

建议语义：

- `governanceCommunity` 一旦确定，默认不在原实例里热切换
- 若群主希望切换治理来源，应优先更换插件实例
- `filterVoteRound + filterActionId` 若启用，必须一起设置

验收条件：

- 非目标群 `owner` / `delegate` 不能初始化该插件
- 缺少 `governanceCommunity` 时初始化必须失败
- 只设置 `filterVoteRound` 或只设置 `filterActionId` 必须失败

### 6.2 提案发起

- 只有当前有资格的治理者可以发起提案
- 每个提案可包含一个或多个目标
- 同一提案内的目标类型可混合：地址、`groupId`
- 提案表达的唯一问题是：这些目标是否应处于黑名单状态
- 提案创建时必须快照治理者集合与治理票权重
- 若快照总治理票为 0，提案必须失败

补充要求：

- 同一目标存在活跃提案时，不能再次进入新的活跃提案
- 单提案目标数量必须有限制，避免 gas 不可控

验收条件：

- 非治理者不能发起提案
- 活跃提案中的目标不能被重复提案

### 6.3 治理者资格

治理者资格按两层条件确定：

- 第一层：必须属于 `governanceCommunity`
- 第二层：若启用 `actionVoteFilter`，必须在 `filterVoteRound + filterActionId` 上投过非零治理票

要求：

- 提案资格以创建时快照为准
- 提案创建后，资格集合不得随链上状态变化而漂移
- 同一地址在单个提案里最多投一次

验收条件：

- 不满足第一层或第二层条件的地址不能投票
- 提案期间失去治理票的地址，其已快照票权仍按提案创建时处理

### 6.4 计票规则

- 计票单位为 LOVE20 治理票
- 每个治理者在单个提案中的票权，等于提案快照时记录的治理票数量
- 不按人数平均
- 不允许创建提案后再动态追加票权

投票选项至少应支持：

- `support`
- `against`

验收条件：

- 已投票治理者不能重复投票
- 支持票、反对票之和不能超过快照总治理票

### 6.5 生效与移除

提案处理规则：

- 当 `supportVotes > snapshotTotalGovernanceVotes / 2` 时，提案立即通过
- 提案立即通过后，其全部目标立即进入黑名单
- 若直到 `deadlineBlock` 仍未达到严格过半支持，则提案拒绝
- 提案拒绝后，其全部目标立即从黑名单中移除，或保持非黑名单状态

补充规则：

- 50% 不通过
- 提案一旦通过或拒绝，状态不可逆
- 同一目标若此前已在黑名单中，后续提案拒绝后应被移出黑名单

验收条件：

- 过半支持时，无需额外执行步骤即可生效
- 未过半支持时，名单状态必须与拒绝结果一致

### 6.6 地址黑名单拦截

若 `senderAddress` 在地址黑名单中：

- `beforePost` 必须拒绝消息发送
- 该地址不能借由自己持有的任意 `groupId` 发言
- 该地址也不能作为其他 `groupId` 的 delegate 发言

验收条件：

- 地址命中黑名单时，消息必须被拒绝

### 6.7 NFT 黑名单拦截

若 `senderGroupId` 在 NFT 黑名单中：

- `beforePost` 必须拒绝消息发送
- 无论当前 owner 是谁、delegate 是谁，都不能使用该 `groupId` 发言
- 即使操作者地址未进入地址黑名单，也不能绕过

验收条件：

- `groupId` 命中黑名单时，消息必须被拒绝

### 6.8 多目标提案

- 单个提案必须支持一组目标批量治理
- 同一提案内的全部目标共享同一套计票结果
- 提案通过时，整组目标一起进入黑名单
- 提案拒绝时，整组目标一起移出黑名单或保持非黑名单

验收条件：

- 一次提案可以处理多个目标
- 同组目标的最终状态必须一致

### 6.9 查询能力

插件至少需要提供：

- 查询地址是否在黑名单
- 查询 `groupId` 是否在黑名单
- 查询提案详情
- 查询提案目标列表
- 查询某地址在某提案中的快照票权与投票状态
- 分页读取提案列表

验收条件：

- 客户端无需依赖中心化数据库也能验证当前状态
- 客户端可根据事件与只读接口增量同步

## 7. 推荐接口

以下接口为建议，不要求 ABI 完全一致，但实现应覆盖等价能力：

### 7.1 初始化

- `initialize(InitParams params)`

`InitParams` 至少应包含：

- `chatGroupId`
- `governanceCommunity`
- `voteDurationBlocks`
- `filterVoteRound`
- `filterActionId`

### 7.2 发消息前检查

- `beforePost(chatGroupId, senderGroupId, senderAddress, content)`

返回语义至少应覆盖：

- 允许发送
- 地址在黑名单
- `senderGroupId` 在黑名单

### 7.3 提案与投票

- `createBlacklistProposal(Target[] targets, string reason, string evidenceURI)`
- `voteBlacklistProposal(uint256 proposalId, bool support)`
- `proposalOf(uint256 proposalId)`
- `proposalTargets(uint256 proposalId, uint256 offset, uint256 limit)`

### 7.4 黑名单查询

- `isAddressBlacklisted(address account)`
- `isGroupBlacklisted(uint256 groupId)`

### 7.5 快照查询

- `proposalVoterSnapshot(uint256 proposalId, address voter)`
- `eligibleVotesOf(uint256 proposalId)`

## 8. 事件需求

### 8.1 必要事件

- `GovernanceBlacklistInitialized`
- `BlacklistProposalCreated`
- `BlacklistVoteCast`
- `BlacklistTargetStatusChanged`
- `BlacklistProposalResolved`

### 8.2 事件字段要求

`GovernanceBlacklistInitialized` 至少应包含：

- `chatGroupId`
- `governanceCommunity`
- `voteDurationBlocks`
- `filterVoteRound`
- `filterActionId`

`BlacklistProposalCreated` 至少应包含：

- `proposalId`
- `proposer`
- `snapshotBlockNumber`
- `snapshotTotalGovernanceVotes`
- `deadlineBlock`

`BlacklistVoteCast` 至少应包含：

- `proposalId`
- `voter`
- `support`
- `votes`

`BlacklistTargetStatusChanged` 至少应包含：

- `proposalId`
- `targetType`
- `targetValue`
- `listed`

`BlacklistProposalResolved` 至少应包含：

- `proposalId`
- `passed`
- `supportVotes`
- `againstVotes`

## 9. 非功能要求

### 9.1 去中心化

- 不存在插件级超级管理员
- 不存在后台人工黑名单入口
- 黑名单结果只能来自治理提案

### 9.2 安全

- 插件不得修改主协议已上链消息
- 插件不得越权修改群聊 owner、delegate、meta、active
- 同一目标不得并发出现在多个活跃提案中
- 快照逻辑必须防止提案期间票权漂移

### 9.3 可审计

- 所有提案、投票、名单变化都必须事件化
- 查询结果必须与事件可对齐

### 9.4 可维护

- 提案列表必须支持分页
- 单提案目标列表必须支持分页
- 黑名单查询应为常量时间或近似常量时间

## 10. 典型流程

### 10.1 初始化

1. 目标群 `owner` 或 `delegate` 挂载本插件
2. 设置 `governanceCommunity`
3. 可选设置 `filterVoteRound + filterActionId`
4. 设置投票时长

### 10.2 拉黑流程

1. 合资格治理者发起提案，目标为一个或多个地址或 `groupId`
2. 插件快照本次治理者集合与治理票权重
3. 治理者投 `support` / `against`
4. 若支持票严格过半，立即把目标加入黑名单
5. 后续 `beforePost` 拒绝这些目标发消息

### 10.3 解除流程

1. 合资格治理者再次对同一目标发起提案
2. 若到截止仍未获严格过半支持
3. 该目标从黑名单中移除，或保持非黑名单

## 11. 验收标准

插件可视为完成，需同时满足：

- 群聊主协议能在 `beforePost` 正常接入该插件
- 地址黑名单能拦截 `senderAddress`
- NFT 黑名单能拦截 `senderGroupId`
- 初始化时必须填写治理来源代币社群
- 可选行动过滤生效后，只有指定行动投票者可参与
- 计票按治理票权重，不按人数
- 严格过半支持时能立即生效
- 截止未过半时目标会被移出黑名单或保持非黑名单
- 所有状态变化都能通过事件和只读接口复原

## 12. 未决问题

实现前需最终定稿：

- `governanceCommunity` 最终用 `tokenAddress` 还是 `tokenSymbol`
- `actionVoteFilter` v1 只支持单个 `actionId`，还是支持多个
- `voteDurationBlocks` 默认值与可调范围
- 单提案 `targets` 最大数量
- 是否允许投票后改票
- 是否需要“数学上已不可能过半”时的提前拒绝
- `reason` 是否仅上链摘要，详细证据走 `evidenceURI`
