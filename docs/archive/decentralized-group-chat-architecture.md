# 去中心化 GroupChat 架构（归档）

- 模块：去中心化 GroupChat 架构
- 状态：归档，仅保留讨论脉络，不参与当前设计
- 说明：该文档中的 `beforePost`、manager、黑名单插件拆分方式已被后续设计推翻。当前设计以 `docs/requirements.md` 入口下的拆分文档为准。

## 1. 身份前提

- `GroupNFT` 更接近链上身份账号 / 链上自媒体账号，不只是“一个群”
- 每个 `GroupNFT` 默认都可激活一个公开 `GroupChat`
- `chatGroupId` 表示群聊所属身份
- `senderGroupId` 表示发言身份
- 地址只是当前控制某个 `GroupNFT` 的签名器，不是协议里的长期身份主体
- 管理、代理、发言的主语都应是 `GroupNFT`
- 地址级黑名单 / 地址级投票仍可作为辅助风控层保留

因此：

- `GroupChat` 的控制权始终跟随 `GroupNFT.ownerOf(chatGroupId)`
- `beforePost` 插件只负责拦截，不接管核心状态
- 去中心化群聊不能依赖中心化管理员地址，而应由专门的 manager 合约持有 `GroupNFT`

## 2. 范围

### 2.1 当前优先落地

- `TokenGovGroupChatManager`
- `ActionGovGroupChatManager`
- `GovVotedBlacklistBeforePostPlugin`

### 2.2 已纳入同一架构的后续类型

- `TokenGroupChatManager`
- `ActionGroupChatManager`

### 2.3 不包含

- 混合群聊
- 依赖 extension 协议稳定性的资格判断
- 提案制黑名单治理
- 链下签名投票
- 自动把被投票对象自己的治理票默认计入 `against`

## 3. 核心原则

### 3.1 身份优先

- `GroupNFT` 是身份账号
- `GroupChat` 是该身份账号激活出的群聊能力
- `senderAddress` 只用于表示实际发起交易的签名地址
- 黑名单治理与发言资格判断应优先针对 `senderGroupId`
- 地址级黑名单与地址级投票保留，但定位为辅助风控层

### 3.2 类型分治

- 不同去中心化群聊类型，使用不同 manager 合约
- 同类型后续若要升级，直接部署该类型的新 manager
- 老版本继续存在，前端按受信地址识别

### 3.3 通用基类

- 各类 manager 共享 `BaseGroupChatManager`
- 基类负责创建、托管、激活、挂插件等通用流程

### 3.4 插件边界

- `beforePost` 插件只负责发言前判断
- manager 负责定义“谁能发言”“谁有治理票权”
- 插件不保存代币、行动等业务绑定关系

### 3.5 代理也用 NFT

- 群聊代理主体应为 `delegateGroupId`，不是地址
- 实际有权限执行管理操作的，是 `delegateGroupId` 当前 owner
- 地址只负责证明“我当前控制这个身份 NFT”

## 4. 组件

### 4.1 BaseGroupChatManager

作用：

- 作为所有去中心化 `GroupChat` manager 的抽象基类
- 统一承载创建与托管流程

建议放入基类的通用能力：

- LOVE20 代币扣费
- 生成 `GroupNFT` 内部技术名
- 调用 `GroupNFT.mint(...)`
- 调用 `GroupChat.activateChat(...)`
- 挂载 `beforePost` 插件
- 通用错误与事件
- 通用 `chatGroupId` 生命周期状态

内部技术名规则：

- 不允许用户提供现有 NFT 或自定义名字
- 名字仅作为无意义技术名
- 生成种子建议为 `keccak256(msg.sender, block.number, localNonce)`
- 若已重名，则递增 `localNonce` 重试

说明：

- 真正唯一性不依赖 `GroupNFT` 名字
- 真正唯一性依赖各子类 manager 的 scope 绑定关系

### 4.2 TokenGovGroupChatManager

职责：

- 持有这类群聊对应的 `GroupNFT`
- 创建并激活代币治理者群聊
- 挂载 `GovVotedBlacklistBeforePostPlugin`
- 提供发言资格查询
- 提供治理黑名单投票权重查询
- 维护 `tokenAddress <-> chatGroupId` 索引

规则：

- 发言资格：当前持有有效治理票的 `senderGroupId`
- 黑名单治理权：当前持有有效治理票的 `voterGroupId`

### 4.3 ActionGovGroupChatManager

职责：

- 持有这类群聊对应的 `GroupNFT`
- 创建并激活行动治理者群聊
- 挂载 `GovVotedBlacklistBeforePostPlugin`
- 提供发言资格查询
- 提供治理黑名单投票权重查询
- 维护 `(tokenAddress, actionId) <-> chatGroupId` 索引

规则：

- 发言资格：基于指定 `tokenAddress + actionId` 的行动治理资格
- 黑名单治理权：该规则下当前有效治理票
- 对外只暴露 `tokenAddress + actionId`
- 若底层需要 `round`，由本合约内部自行解释，前端与插件不直接感知

### 4.4 TokenGroupChatManager

职责：

- 持有这类群聊对应的 `GroupNFT`
- 创建并激活面向代币社区更宽口径成员的去中心化群聊
- 可复用 `GovVotedBlacklistBeforePostPlugin`
- 提供发言资格查询
- 提供治理黑名单投票权重查询
- 维护 `tokenAddress <-> chatGroupId` 索引

规则：

- 发言资格可包含：
- 有治理票
- 参加过行动
- 持有代币
- 黑名单治理权仍建议只由治理者决定

### 4.5 ActionGroupChatManager

职责：

- 持有这类群聊对应的 `GroupNFT`
- 创建并激活面向特定行动相关成员的去中心化群聊
- 可复用 `GovVotedBlacklistBeforePostPlugin`
- 提供发言资格查询
- 提供治理黑名单投票权重查询
- 维护 `(tokenAddress, actionId) <-> chatGroupId` 索引

规则：

- 发言资格与 `TokenGroupChatManager` 类似
- 但范围限制在指定 `tokenAddress + actionId`
- 例如：
- 对该行动投过票
- 参与过该行动
- 黑名单治理权仍建议只由治理者决定

### 4.6 GovVotedBlacklistBeforePostPlugin

职责：

- 作为 `beforePost` 插件接入 `GroupChat`
- 判定 `senderGroupId` 当前是否有发言资格
- 判定 `senderAddress` 是否在地址黑名单
- 判定 `senderGroupId` 是否在身份黑名单
- 维护治理者对目标地址或目标 `senderGroupId` 的显式投票
- 维护目标当前 `supportWeight` / `againstWeight`
- 通过 `revalidate` 重算显式投票者当前有效票权

边界：

- 不持有 `GroupNFT`
- 不定义资格规则
- 不保存 `tokenAddress` / `actionId` 等资格配置
- `senderAddress` 仅作为 hook 上下文和地址级风控主体，不作为长期身份主体
- 只依赖 owner 合约实现的统一接口 `IGovBlacklistSource`

适用范围：

- 凡是希望由治理者对地址和身份 NFT 做去中心化黑名单管理的群聊，都可复用该插件

### 4.7 IGovBlacklistSource

作用：

- 作为 `GovVotedBlacklistBeforePostPlugin` 依赖的统一只读接口
- 由各类 `GroupChatManager` 实现

插件只依赖两类能力：

- 某 `senderGroupId` 当前是否可在指定 `chatGroupId` 下发言
- 某 `voterGroupId` 当前在指定 `chatGroupId` 下的有效票权

## 5. 前端识别

前端不信任合约自报类型，只信任受信地址表。

识别流程：

1. 读取 `GroupNFT.ownerOf(chatGroupId)`
2. 若 owner 命中受信的 `TokenGovGroupChatManager` 地址，按代币治理者群聊渲染
3. 若 owner 命中受信的 `ActionGovGroupChatManager` 地址，按行动治理者群聊渲染
4. 若 owner 命中受信的 `TokenGroupChatManager` 地址，按代币社区群聊渲染
5. 若 owner 命中受信的 `ActionGroupChatManager` 地址，按行动社区群聊渲染
6. 若都未命中，则按普通群聊渲染

## 6. 命名约定

所有 `groupId` 都必须带前缀：

- `chatGroupId`
- `senderGroupId`
- `delegateGroupId`
- `voterGroupId`

不再使用裸 `groupId`。

## 7. 对象模型

### 7.1 TokenGovGroupChat

每个代币治理者群聊至少包含：

- `chatGroupId`
- `tokenAddress`

### 7.2 ActionGovGroupChat

每个行动治理者群聊至少包含：

- `chatGroupId`
- `tokenAddress`
- `actionId`

### 7.3 TokenGroupChat

每个代币社区群聊至少包含：

- `chatGroupId`
- `tokenAddress`

### 7.4 ActionGroupChat

每个行动社区群聊至少包含：

- `chatGroupId`
- `tokenAddress`
- `actionId`

### 7.5 VoteStance

建议：

- `0 = None`
- `1 = Support`
- `2 = Against`

### 7.6 SenderGroupIdBlacklistState

每个 `chatGroupId + senderGroupId` 至少包含：

- `listed`
- `supportWeight`
- `againstWeight`

### 7.7 AddressBlacklistState

每个 `chatGroupId + targetAddress` 至少包含：

- `listed`
- `supportWeight`
- `againstWeight`

### 7.8 VoteRecord

每个“目标地址 + voterGroupId”或“目标 `senderGroupId` + voterGroupId”至少包含：

- `stance`
- `settledWeight`

说明：

- `settledWeight` 是该 `voterGroupId` 上一次结算到此目标上的票权
- `revalidate` 时通过当前票权与 `settledWeight` 的差值更新聚合票数

## 8. 核心规则

### 8.1 两套资格

每个去中心化 `GroupChatManager` 都应分别定义：

- `canPost(...)`
- `currentVoterWeight(...)`

前者表示：

- 谁能发言

后者表示：

- 谁能参与治理黑名单，以及当前票权是多少

### 8.2 发言资格

`GovVotedBlacklistBeforePostPlugin.beforePost(...)` 至少按以下顺序判定：

1. 通过 owner 合约判断 `senderGroupId` 当前是否有资格在 `chatGroupId` 发言
2. 检查 `senderAddress` 是否在地址黑名单
3. 检查 `senderGroupId` 是否在身份黑名单
4. 三者都通过才允许发送

说明：

- `senderGroupId` 是主身份主体
- `senderAddress` 是辅助风控主体
- 主协议仍应先保证 `msg.sender` 是 `senderGroupId` 当前 owner
- 若插件关心 `mentionedSenderIds` / `mentionAll` / `quotedMessageIndex`，也应在 `beforePost(...)` 中自行判定；主协议只透传，不额外决策

### 8.3 黑名单投票

- 治理者可直接对目标地址或目标 `senderGroupId` 投票，不走提案制
- 投票主体是 `voterGroupId`
- 只有显式投票才计票
- 不自动为被投票对象追加 `against`
- 发起投票的地址必须证明自己当前控制 `voterGroupId`

### 8.4 黑名单成立条件

目标进入黑名单的条件是：

- `supportWeight > againstWeight`

否则：

- 从黑名单移除，或保持非黑名单状态

### 8.5 重验证

- 任何人都可触发 `revalidate`
- `revalidate` 只针对“某个 `voterGroupId` 对某个地址或某个 `senderGroupId` 的显式投票”
- 插件读取该 `voterGroupId` 当前有效票权
- 用当前票权与 `settledWeight` 的差值修正聚合票数
- 修正后立即重算该目标是否应处于黑名单

## 9. 最小接口

### 9.1 IGovBlacklistSource

```solidity
interface IGovBlacklistSource {
    function canPost(
        uint256 chatGroupId,
        uint256 senderGroupId
    ) external view returns (bool);

    function currentVoterWeight(
        uint256 chatGroupId,
        uint256 voterGroupId
    ) external view returns (uint256);
}
```

### 9.2 BaseGroupChatManager

```solidity
abstract contract BaseGroupChatManager is IGovBlacklistSource {
    function _ensureScopeAvailable(bytes32 scopeKey) internal view virtual;
    function _bindScope(bytes32 scopeKey, uint256 chatGroupId) internal virtual;
}
```

### 9.3 TokenGovGroupChatManager

```solidity
interface ITokenGovGroupChatManager is IGovBlacklistSource {
    function governanceTokenAddressOf(
        uint256 chatGroupId
    ) external view returns (address);

    function chatGroupIdOfGovernanceToken(
        address tokenAddress
    ) external view returns (uint256);
}
```

### 9.4 ActionGovGroupChatManager

```solidity
interface IActionGovGroupChatManager is IGovBlacklistSource {
    function actionBindingOf(
        uint256 chatGroupId
    ) external view returns (address tokenAddress, uint256 actionId);

    function chatGroupIdOfAction(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256);
}
```

### 9.5 TokenGroupChatManager

```solidity
interface ITokenGroupChatManager is IGovBlacklistSource {
    function tokenAddressOf(
        uint256 chatGroupId
    ) external view returns (address);

    function chatGroupIdOfToken(
        address tokenAddress
    ) external view returns (uint256);
}
```

### 9.6 ActionGroupChatManager

```solidity
interface IActionGroupChatManager is IGovBlacklistSource {
    function actionBindingOf(
        uint256 chatGroupId
    ) external view returns (address tokenAddress, uint256 actionId);

    function chatGroupIdOfAction(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256);
}
```

### 9.7 GovVotedBlacklistBeforePostPlugin

```solidity
interface IGovVotedBlacklistBeforePostPlugin {
    function beforePost(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external;

    function voteAddress(
        uint256 chatGroupId,
        uint256 voterGroupId,
        address targetAddress,
        uint8 stance
    ) external;

    function voteSenderGroupId(
        uint256 chatGroupId,
        uint256 voterGroupId,
        uint256 targetSenderGroupId,
        uint8 stance
    ) external;

    function revalidateAddressVote(
        uint256 chatGroupId,
        address targetAddress,
        uint256 voterGroupId
    ) external;

    function revalidateSenderGroupIdVote(
        uint256 chatGroupId,
        uint256 targetSenderGroupId,
        uint256 voterGroupId
    ) external;

    function addressBlacklistState(
        uint256 chatGroupId,
        address targetAddress
    ) external view returns (
        bool listed,
        uint256 supportWeight,
        uint256 againstWeight
    );

    function senderGroupIdBlacklistState(
        uint256 chatGroupId,
        uint256 senderGroupId
    ) external view returns (
        bool listed,
        uint256 supportWeight,
        uint256 againstWeight
    );
}
```

## 10. 建议状态

### 10.1 BaseGroupChatManager

建议至少维护：

- `address GROUP_CHAT`
- `address GROUP_NFT`
- `address LOVE20_TOKEN`
- `address BEFORE_POST_PLUGIN`
- `uint256 localNonce`

### 10.2 TokenGovGroupChatManager

建议至少维护：

- `mapping(uint256 => address) governanceTokenAddressByChatGroupId`
- `mapping(address => uint256) chatGroupIdByGovernanceTokenAddress`

### 10.3 ActionGovGroupChatManager

建议至少维护：

- `mapping(uint256 => address) tokenAddressByChatGroupId`
- `mapping(uint256 => uint256) actionIdByChatGroupId`
- `mapping(address => mapping(uint256 => uint256)) chatGroupIdByTokenAddressByActionId`

### 10.4 TokenGroupChatManager

建议至少维护：

- `mapping(uint256 => address) tokenAddressByChatGroupId`
- `mapping(address => uint256) chatGroupIdByTokenAddress`

### 10.5 ActionGroupChatManager

建议至少维护：

- `mapping(uint256 => address) tokenAddressByChatGroupId`
- `mapping(uint256 => uint256) actionIdByChatGroupId`
- `mapping(address => mapping(uint256 => uint256)) chatGroupIdByTokenAddressByActionId`

### 10.6 GovVotedBlacklistBeforePostPlugin

建议至少维护：

- `mapping(uint256 => mapping(address => AddressBlacklistState))`
- `mapping(uint256 => mapping(uint256 => SenderGroupIdBlacklistState))`
- `mapping(uint256 => mapping(address => mapping(uint256 => VoteRecord)))`
- `mapping(uint256 => mapping(uint256 => mapping(uint256 => VoteRecord)))`

## 11. 关键流程

### 11.1 通用创建流程

1. 用户授权 LOVE20 给某个 `GroupChatManager`
2. manager 检查对应 scope 尚未绑定
3. manager 拉取 LOVE20
4. manager 生成无意义技术名
5. manager 调用 `GroupNFT.mint(...)`
6. manager 调用 `GroupChat.activateChat(...)`
7. manager 挂载 `GovVotedBlacklistBeforePostPlugin`
8. manager 写入自身 scope 绑定映射

### 11.2 发送消息

1. 用户调用 `GroupChat.post(chatGroupId, senderGroupId, content, mentionedSenderIds, mentionAll, quotedMessageIndex)`，或先设置默认身份后调用 `postByDefaultSender(...)`
2. 主协议先校验 `msg.sender` 是否为 `senderGroupId` 当前 owner
3. 主协议先校验 `quotedMessageIndex`，再将 `content`、`mentionedSenderIds`、`mentionAll`、`quotedMessageIndex` 原样传给 `beforePost` 插件
4. 插件通过 `GroupNFT.ownerOf(chatGroupId)` 识别当前 owner manager
5. 插件将该 owner 视为 `IGovBlacklistSource`
6. 先调用 `canPost(chatGroupId, senderGroupId)`
7. 再检查地址黑名单与身份黑名单
8. 若插件需要限制 `mentionAll`，也在此阶段判定
9. 全部通过则放行，否则拒绝

### 11.3 黑名单投票

1. 治理者使用 `voterGroupId` 对目标地址或目标 `senderGroupId` 显式投票
2. 插件校验 `msg.sender` 当前控制 `voterGroupId`
3. 插件读取该 `voterGroupId` 当前票权
4. 若已有旧投票，先扣除旧 `settledWeight`
5. 再按新 `stance` 加上新权重
6. 更新 `VoteRecord`
7. 重算 `listed`

### 11.4 重验证

1. 任意地址指定目标地址或目标 `senderGroupId` 与 `voterGroupId` 发起 `revalidate`
2. 插件读取该 `voterGroupId` 当前票权
3. 比较当前票权与 `settledWeight`
4. 修正目标聚合票数
5. 更新 `VoteRecord`
6. 重算 `listed`

## 12. 设计结论

- 不同去中心化群聊类型，使用不同 manager 合约
- 各类 manager 共享 `BaseGroupChatManager` 的通用创建与托管流程
- `GovVotedBlacklistBeforePostPlugin` 作为治理黑名单插件复用
- 前端按受信 manager 地址识别群聊类型
- 群聊、代理、发言、投票都以 `GroupNFT` 身份为主语
- 地址只作为当前控制某个 `GroupNFT` 的签名器，并保留辅助风控用途
