# GovVotedDenySource

治理投票型黑名单 DenySource。

状态：已实现。

## 定位

`GovVotedDenySource` 负责通过投票产生黑名单。这里的 `Gov` 表示“由投票治理产生”，不限定票权必须来自 token 治理票。

不同群聊的差异来自对应 `IDenyVoteWeightSource`：

- token 群：token 治理票
- token gov 群：token 治理票
- token action 群：当前行动轮投票数
- token action gov 群：当前行动轮投票数

## 主协议挂载

```text
GroupChat.denySource = GovVotedDenySource
票权源 = ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId)
```

去中心化群聊的 `groupId` owner 是对应 Manager。该 Manager 必须实现 `IDenyVoteWeightSource`，为本合约提供 `denyVoteWeightOf(...)`。

## 可配置项

构造参数固定外部依赖和全局黑名单生效阈值：

- `GROUP_ADDRESS`
- `GROUP_DEFAULTS_ADDRESS`
- `DENY_THRESHOLD_BPS`

当前部署默认值：

- `DENY_THRESHOLD_BPS = 30`，即支持禁言票数至少占总治理票 `0.3%`

比例单位是 basis points，`10000 = 100%`。

治理语义硬编码固定：

- 实时计票
- 支持反对票
- 支持撤票
- 支持复议

构造后不按群重配这些治理规则，也不通过构造参数开启 / 关闭这些能力。

如果未来需要“不支持反对票”“不可撤票”“不可复议”等不同治理语义，应新增独立 DenySource 合约类型，不在 `GovVotedDenySource` 内增加模式开关。

实时计票含义：

- 不设置提案开始 / 结束窗口。
- 每次投票、反对、撤票、复议重验证都立即更新聚合票权。
- 每次聚合票权变化后，同步更新“已命中黑名单”结果。
- 命中黑名单结果必须同时满足：
  - `supportWeight > opposeWeight`
  - `supportWeight / denyVoteTotalWeightOf(groupId) >= DENY_THRESHOLD_BPS / 10000`
- `DENY_THRESHOLD_BPS` 只在投票、反对、撤票、复议等写入/结算路径读取；`isDenied(...)` 仅读取已结算名单。
- 地址黑名单或 `senderId` 黑名单任一命中，`isDenied(...)` 返回 `true`。

## 投票模型

- 投票主体是 `address voter = msg.sender`。
- 不引入 `voterGroupId`；治理票来自地址维度的流动性质押，票权源按 `voter` 地址计算。
- `senderId` 只作为被投票目标维度，不作为投票人身份。
- 每个投票主体对同一目标只有一个当前立场：无票、赞成拉黑、反对拉黑。
- 基础目标分两类：`targetAddress` 与 `targetSenderId`，接口层分开，不用“二选一参数”。
- `*BySenderId` 通过 `ownerOf(targetSenderId)` 解析目标地址，一次操作同步影响地址与 NFT 两个目标维度。
- `*BySenderAddress` 直接影响地址目标；若 `defaultGroupIdOf(targetAddress) != 0` 且该 NFT 当前 owner 仍是 `targetAddress`，同时影响 NFT 目标，否则不处理 NFT 且不拒绝。
- `voteDeny*` 会用当前票权覆盖旧立场。
- `opposeDeny*` 是反对票，也是一种复议手段。
- `clearDeny*Vote` 只撤回 `msg.sender` 自己的当前票。
- `revalidateDeny*Vote` 是复议重验证：任何人都可刷新某个 voter 对某个目标的当前票权。
- `revalidateDeny*Vote` 后当前票权为 `0` 时，必须删除该 voter 对该目标的当前票。
- 目标名单只包含当前至少有一个投票人的目标。
- 另外维护已结算地址黑名单和已结算 `senderId` 黑名单，供 `isDenied(...)` 与前端批量读使用。
- 某目标最后一个投票人撤票或被重验证删除后，该目标必须从目标名单移除。
- 地址目标读取票权时调用 `denyVoteWeightOf(groupId, voter)`。
- `senderId` 目标读取票权时调用 `denyVoteWeightOf(groupId, voter)`。
- 禁言阈值的分母读取 `denyVoteTotalWeightOf(groupId)`。
- 四个 typed Manager 的 `denyVoteTotalWeightOf(groupId)` 均返回 `ILOVE20Stake.govVotesNum(token)`。

## 最小接口

```solidity
function voteDenyAddress(
    uint256 groupId,
    address targetAddress
) external;

function opposeDenyAddress(
    uint256 groupId,
    address targetAddress
) external;

function clearDenyAddressVote(
    uint256 groupId,
    address targetAddress
) external;

function revalidateDenyAddressVote(
    uint256 groupId,
    address targetAddress,
    address voter
) external;

function voteDenySenderId(
    uint256 groupId,
    uint256 targetSenderId
) external;

function opposeDenySenderId(
    uint256 groupId,
    uint256 targetSenderId
) external;

function clearDenySenderIdVote(
    uint256 groupId,
    uint256 targetSenderId
) external;

function revalidateDenySenderIdVote(
    uint256 groupId,
    uint256 targetSenderId,
    address voter
) external;

function voteDenySenderBySenderId(
    uint256 groupId,
    uint256 targetSenderId
) external;

function opposeDenySenderBySenderId(
    uint256 groupId,
    uint256 targetSenderId
) external;

function clearDenySenderVoteBySenderId(
    uint256 groupId,
    uint256 targetSenderId
) external;

function revalidateDenySenderVoteBySenderId(
    uint256 groupId,
    uint256 targetSenderId,
    address voter
) external;

function voteDenySenderBySenderAddress(
    uint256 groupId,
    address targetAddress
) external;

function opposeDenySenderBySenderAddress(
    uint256 groupId,
    address targetAddress
) external;

function clearDenySenderVoteBySenderAddress(
    uint256 groupId,
    address targetAddress
) external;

function revalidateDenySenderVoteBySenderAddress(
    uint256 groupId,
    address targetAddress,
    address voter
) external;

function addressDenyVoteOf(
    uint256 groupId,
    address targetAddress,
    address voter
) external view returns (bool supportDeny, uint256 settledWeight);

function senderIdDenyVoteOf(
    uint256 groupId,
    uint256 targetSenderId,
    address voter
) external view returns (bool supportDeny, uint256 settledWeight);

function addressDenyTallyOf(
    uint256 groupId,
    address targetAddress
) external view returns (uint256 supportWeight, uint256 opposeWeight);

function addressDenyDetailsBatch(
    uint256 groupId,
    address[] calldata targetAddresses
) external view returns (
    bool[] memory denied,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
);

function senderIdDenyTallyOf(
    uint256 groupId,
    uint256 targetSenderId
) external view returns (uint256 supportWeight, uint256 opposeWeight);

function senderIdDenyDetailsBatch(
    uint256 groupId,
    uint256[] calldata targetSenderIds
) external view returns (
    bool[] memory denied,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
);

function addressDenyTargetsCount(
    uint256 groupId
) external view returns (uint256);

function addressDenyTargets(
    uint256 groupId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory targetAddresses,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function senderIdDenyTargetsCount(
    uint256 groupId
) external view returns (uint256);

function senderIdDenyTargets(
    uint256 groupId,
    uint256 offset,
    uint256 limit
) external view returns (
    uint256[] memory targetSenderIds,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function addressDenyVotersCount(
    uint256 groupId,
    address targetAddress
) external view returns (uint256);

function addressDenyVoters(
    uint256 groupId,
    address targetAddress,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    bool[] memory supportDenies,
    uint256[] memory settledWeights
);

function senderIdDenyVotersCount(
    uint256 groupId,
    uint256 targetSenderId
) external view returns (uint256);

function senderIdDenyVoters(
    uint256 groupId,
    uint256 targetSenderId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    bool[] memory supportDenies,
    uint256[] memory settledWeights
);

function isDenied(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external view returns (bool);

function isAddressDenied(
    uint256 groupId,
    address senderAddress
) external view returns (bool);

function isSenderIdDenied(
    uint256 groupId,
    uint256 senderId
) external view returns (bool);

function isSenderIdExempt(
    uint256 groupId,
    uint256 senderId
) external view returns (bool);

function isAddressDeniedBatch(
    uint256 groupId,
    address[] calldata senderAddresses
) external view returns (bool[] memory denied);

function isSenderIdDeniedBatch(
    uint256 groupId,
    uint256[] calldata senderIds
) external view returns (bool[] memory denied);

function isSenderIdExemptBatch(
    uint256 groupId,
    uint256[] calldata senderIds
) external view returns (bool[] memory exempt);

function stateVersion(
    uint256 groupId
) external view returns (uint256);
```

## 接口规则

- 票权源固定为 `ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId)`。
- 票权源必须是合约，并实现 `IDenyVoteWeightSource`；这是 Manager 与部署测试约束。
- 票权源不可用时，投票、反对、撤票、复议写接口必须拒绝。
- 票权源不可用时，即 `ownerOf(groupId)` 失败或 owner 无代码，`*DenyTallyOf(...)` 返回 `0, 0`，投票分页接口返回空。
- `isDenied(...)`、`isAddressDeniedBatch(...)`、`isSenderIdDeniedBatch(...)` 仅读取已结算名单，不重新读取总票权。
- 通用批量黑名单读接口只返回发言 / 隐藏判断所需的布尔状态，不返回治理票数。
- 如果前端需要按指定地址或 `senderId` 解释治理黑名单原因，使用 `addressDenyDetailsBatch(...)`、`senderIdDenyDetailsBatch(...)` 一次读取 `denied`、`supportWeight`、`opposeWeight`。
- 详情批量接口只读取已结算名单和当前存储的聚合票数，不重新读取票权源或总票权。
- 如果前端需要目标列表或投票人明细，继续使用 `addressDenyTargets(...)`、`senderIdDenyTargets(...)` 或对应 voters 分页。
- `targetAddress == address(0)` 必须拒绝。
- `targetSenderId == 0` 必须拒绝。
- 单个 voter 当前无票时，`*DenyVoteOf(...)` 返回 `supportDeny=false, settledWeight=0`。
- `settledWeight == 0` 表示无当前票；`settledWeight > 0` 时 `supportDeny` 才表示支持或反对。
- `voteDeny*` 和 `opposeDeny*` 读取到的当前票权必须 `> 0`，否则拒绝。
- 重复投相同立场且票权未变化时必须拒绝。
- 已无当前票时调用 `clearDeny*Vote(...)` 必须拒绝。
- `revalidateDeny*Vote(...)` 只处理已有当前票的 voter；无当前票必须拒绝。
- `revalidateDeny*Vote(...)` 读取到当前票权为 `0` 时，必须等价于删除该 voter 当前票。
- `revalidateDeny*Vote(...)` 读取到当前票权未变化，但总票权阈值导致黑名单结果变化时，必须更新已结算名单并递增 `stateVersion`。
- 单目标是否命中由写入/复议路径根据 `supportWeight > opposeWeight` 与全局阈值同步到已结算名单。
- `isAddressDeniedBatch(...)`、`isSenderIdDeniedBatch(...)`、`isSenderIdExemptBatch(...)` 返回顺序必须与入参数组顺序一致。
- `addressDenyDetailsBatch(...)`、`senderIdDenyDetailsBatch(...)` 返回的三组数组长度和顺序必须与入参数组一致；未出现过的目标返回 `denied=false, supportWeight=0, opposeWeight=0`。
- `GovVotedDenySource` 没有豁免名单，`isSenderIdExemptBatch(...)` 必须返回同长度的全 `false`。
- 分页接口 `limit == 0` 或 `offset` 越界时返回空数组。
- 同一分页接口返回的数组长度必须一致。
- 目标与投票人列表必须去重，返回顺序不作协议承诺。
- 任意外部投票写调用发生至少一项实际状态变化时，必须递增一次对应 `groupId` 的 `stateVersion`。
- `*DenySender*` 联动写接口若同时改变地址目标和 NFT 目标，两条明细事件必须使用同一个 `stateVersion`，且只发出一条 `StateVersionChanged`。

## 最小事件

```solidity
event AddressDenyVoteSet(
    uint256 indexed groupId,
    address indexed targetAddress,
    address indexed voter,
    bool supportDeny,
    uint256 settledWeight,
    uint256 supportWeight,
    uint256 opposeWeight,
    uint256 stateVersion
);

event SenderIdDenyVoteSet(
    uint256 indexed groupId,
    uint256 indexed targetSenderId,
    address indexed voter,
    bool supportDeny,
    uint256 settledWeight,
    uint256 supportWeight,
    uint256 opposeWeight,
    uint256 stateVersion
);

event AddressDenySet(
    uint256 indexed groupId,
    address indexed targetAddress,
    bool listed,
    uint256 stateVersion
);

event SenderIdDenySet(
    uint256 indexed groupId,
    uint256 indexed targetSenderId,
    bool listed,
    uint256 stateVersion
);

event StateVersionChanged(
    uint256 indexed groupId,
    uint256 stateVersion
);
```

投票聚合状态发生变化时，统一发对应的 `*DenyVoteSet` 明细事件。
已结算黑名单结果发生变化时，必须发对应的 `*DenySet` 明细事件。

## 状态要求

合约全局至少维护：

- `address immutable GROUP_ADDRESS`
- `address immutable GROUP_DEFAULTS_ADDRESS`

每个 `groupId` 至少维护：

- `uint256 stateVersion`
- `address[] addressDenyTargets` 与对应 `indexPlusOne`
- `uint256[] senderIdDenyTargets` 与对应 `indexPlusOne`
- `address[] addressDenyList` 与对应 `indexPlusOne`
- `uint256[] senderIdDenyList` 与对应 `indexPlusOne`

每个地址目标至少维护：

- `supportWeight`
- `opposeWeight`
- `address[] voters` 与对应 `indexPlusOne`
- 每个 voter 的 `supportDeny`、`settledWeight`

每个 `senderId` 目标至少维护同样的聚合票权、投票人列表和 voter 投票状态。

## Review 重点

- 不把票权语义写死成 token gov vote。
- 不在 DenySource 内直接读取 LOVE20 token/action 状态。
- 对目标支持地址维度和 `senderId` 维度。
- 投票权重源必须由群类型 Manager 提供。
- 投票人必须是地址，不引入 `voterGroupId`。
- 不做全量重算接口，避免 `isDenied(...)` 或复议写入依赖不可控循环。
- `0` 票权不能新增或改投；复议重验证为 `0` 时必须删除旧票。
