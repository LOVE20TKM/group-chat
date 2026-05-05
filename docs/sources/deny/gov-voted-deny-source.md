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
票权源 = ILOVE20Group(GROUP_ADDRESS).ownerOf(chatGroupId)
```

去中心化群聊的 `chatGroupId` owner 是对应 Manager。该 Manager 必须实现 `IDenyVoteWeightSource`，为本合约提供 `denyVoteWeightOf(...)`。

## 可配置项

无独立可配置项。

构造参数只固定外部依赖：

- `GROUP_ADDRESS`
- `GROUP_DEFAULTS`

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
- `supportWeight > opposeWeight` 时命中黑名单，否则不命中。
- 地址目标或 `senderGroupId` 目标任一命中，`isDenied(...)` 返回 `true`。

## 投票模型

- 投票主体是 `address voter = msg.sender`。
- 不引入 `voterGroupId`；治理票来自地址维度的流动性质押，票权源按 `voter` 地址计算。
- `senderGroupId` 只作为被投票目标维度，不作为投票人身份。
- 每个投票主体对同一目标只有一个当前立场：无票、赞成拉黑、反对拉黑。
- 基础目标分两类：`targetAddress` 与 `targetSenderGroupId`，接口层分开，不用“二选一参数”。
- `*BySenderGroupId` 通过 `ownerOf(targetSenderGroupId)` 解析目标地址，一次操作同步影响地址与 NFT 两个目标维度。
- `*BySenderAddress` 直接影响地址目标；若 `defaultGroupIdOf(targetAddress) != 0` 且该 NFT 当前 owner 仍是 `targetAddress`，同时影响 NFT 目标，否则不处理 NFT 且不拒绝。
- `voteDeny*` 会用当前票权覆盖旧立场。
- `opposeDeny*` 是反对票，也是一种复议手段。
- `clearDeny*Vote` 只撤回 `msg.sender` 自己的当前票。
- `revalidateDeny*Vote` 是复议重验证：任何人都可刷新某个 voter 对某个目标的当前票权。
- `revalidateDeny*Vote` 后当前票权为 `0` 时，必须删除该 voter 对该目标的当前票。
- 目标名单只包含当前至少有一个投票人的目标，不单独维护“已命中黑名单”派生列表。
- 某目标最后一个投票人撤票或被重验证删除后，该目标必须从目标名单移除。
- 地址目标读取票权时调用 `denyVoteWeightOf(chatGroupId, voter, targetAddress, 0)`。
- `senderGroupId` 目标读取票权时调用 `denyVoteWeightOf(chatGroupId, voter, address(0), targetSenderGroupId)`。

## 最小接口

```solidity
function voteDenyAddress(
    uint256 chatGroupId,
    address targetAddress
) external;

function opposeDenyAddress(
    uint256 chatGroupId,
    address targetAddress
) external;

function clearDenyAddressVote(
    uint256 chatGroupId,
    address targetAddress
) external;

function revalidateDenyAddressVote(
    uint256 chatGroupId,
    address targetAddress,
    address voter
) external;

function voteDenySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function opposeDenySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function clearDenySenderGroupIdVote(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function revalidateDenySenderGroupIdVote(
    uint256 chatGroupId,
    uint256 targetSenderGroupId,
    address voter
) external;

function voteDenySenderBySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function opposeDenySenderBySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function clearDenySenderVoteBySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external;

function revalidateDenySenderVoteBySenderGroupId(
    uint256 chatGroupId,
    uint256 targetSenderGroupId,
    address voter
) external;

function voteDenySenderBySenderAddress(
    uint256 chatGroupId,
    address targetAddress
) external;

function opposeDenySenderBySenderAddress(
    uint256 chatGroupId,
    address targetAddress
) external;

function clearDenySenderVoteBySenderAddress(
    uint256 chatGroupId,
    address targetAddress
) external;

function revalidateDenySenderVoteBySenderAddress(
    uint256 chatGroupId,
    address targetAddress,
    address voter
) external;

function addressDenyVoteOf(
    uint256 chatGroupId,
    address targetAddress,
    address voter
) external view returns (bool hasVote, bool supportDeny, uint256 settledWeight);

function senderGroupIdDenyVoteOf(
    uint256 chatGroupId,
    uint256 targetSenderGroupId,
    address voter
) external view returns (bool hasVote, bool supportDeny, uint256 settledWeight);

function addressDenyTallyOf(
    uint256 chatGroupId,
    address targetAddress
) external view returns (uint256 supportWeight, uint256 opposeWeight);

function senderGroupIdDenyTallyOf(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external view returns (uint256 supportWeight, uint256 opposeWeight);

function addressDenyTargetsCount(
    uint256 chatGroupId
) external view returns (uint256);

function addressDenyTargets(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory targetAddresses,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function senderGroupIdDenyTargetsCount(
    uint256 chatGroupId
) external view returns (uint256);

function senderGroupIdDenyTargets(
    uint256 chatGroupId,
    uint256 offset,
    uint256 limit
) external view returns (
    uint256[] memory targetSenderGroupIds,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function addressDenyVotersCount(
    uint256 chatGroupId,
    address targetAddress
) external view returns (uint256);

function addressDenyVoters(
    uint256 chatGroupId,
    address targetAddress,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    bool[] memory supportDenies,
    uint256[] memory settledWeights
);

function senderGroupIdDenyVotersCount(
    uint256 chatGroupId,
    uint256 targetSenderGroupId
) external view returns (uint256);

function senderGroupIdDenyVoters(
    uint256 chatGroupId,
    uint256 targetSenderGroupId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    bool[] memory supportDenies,
    uint256[] memory settledWeights
);

function isDenied(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress
) external view returns (bool);

function stateVersion(
    uint256 chatGroupId
) external view returns (uint256);
```

## 接口规则

- 票权源固定为 `ILOVE20Group(GROUP_ADDRESS).ownerOf(chatGroupId)`。
- 票权源必须是合约，并实现 `IDenyVoteWeightSource`；这是 Manager 与部署测试约束，读路径不做通用 ABI 探测。
- 票权源不可用时，投票、反对、撤票、复议写接口必须拒绝。
- 票权源不可用时，即 `ownerOf(chatGroupId)` 失败或 owner 无代码，`isDenied(...)` 返回 `false`，`*DenyTallyOf(...)` 返回 `0, 0`，分页接口返回空。
- `targetAddress == address(0)` 必须拒绝。
- `targetSenderGroupId == 0` 必须拒绝。
- `hasVote == false` 时，`supportDeny` 无意义，前端必须忽略。
- `voteDeny*` 和 `opposeDeny*` 读取到的当前票权必须 `> 0`，否则拒绝。
- 重复投相同立场且票权未变化时必须拒绝。
- 已无当前票时调用 `clearDeny*Vote(...)` 必须拒绝。
- `revalidateDeny*Vote(...)` 只处理已有当前票的 voter；无当前票必须拒绝。
- `revalidateDeny*Vote(...)` 读取到当前票权为 `0` 时，必须等价于删除该 voter 当前票。
- `revalidateDeny*Vote(...)` 读取到当前票权未变化时，不得递增 `stateVersion` 或发事件。
- 单目标是否命中不单独提供接口，由 `*DenyTallyOf(...)` 的 `supportWeight > opposeWeight` 推导。
- 分页接口 `limit == 0` 或 `offset` 越界时返回空数组。
- 同一分页接口返回的数组长度必须一致。
- 目标与投票人列表必须去重，返回顺序不作协议承诺。
- 任意实际状态变化都必须递增对应 `chatGroupId` 的 `stateVersion`。

## 最小事件

```solidity
event AddressDenyVoteSet(
    uint256 indexed chatGroupId,
    address indexed targetAddress,
    address indexed voter,
    bool hasVote,
    bool supportDeny,
    uint256 settledWeight,
    uint256 supportWeight,
    uint256 opposeWeight,
    uint256 stateVersion
);

event SenderGroupIdDenyVoteSet(
    uint256 indexed chatGroupId,
    uint256 indexed targetSenderGroupId,
    address indexed voter,
    bool hasVote,
    bool supportDeny,
    uint256 settledWeight,
    uint256 supportWeight,
    uint256 opposeWeight,
    uint256 stateVersion
);

event StateVersionChanged(
    uint256 indexed chatGroupId,
    uint256 stateVersion
);
```

`vote`、`oppose`、`clear`、`revalidate` 发生实际状态变化时，统一发对应的 `*DenyVoteSet` 事件。

## 状态要求

合约全局至少维护：

- `address immutable GROUP_ADDRESS`
- `address immutable GROUP_DEFAULTS`

每个 `chatGroupId` 至少维护：

- `uint256 stateVersion`
- `address[] addressDenyTargets` 与对应 `indexPlusOne`
- `uint256[] senderGroupIdDenyTargets` 与对应 `indexPlusOne`

每个地址目标至少维护：

- `supportWeight`
- `opposeWeight`
- `address[] voters` 与对应 `indexPlusOne`
- 每个 voter 的 `hasVote`、`supportDeny`、`settledWeight`

每个 `senderGroupId` 目标至少维护同样的聚合票权、投票人列表和 voter 投票状态。

## Review 重点

- 不把票权语义写死成 token gov vote。
- 不在 DenySource 内直接读取 LOVE20 token/action 状态。
- 对目标支持地址维度和 `senderGroupId` 维度。
- 投票权重源必须由群类型 Manager 提供。
- 投票人必须是地址，不引入 `voterGroupId`。
- 不做全量重算接口，避免 `isDenied(...)` 或复议写入依赖不可控循环。
- `0` 票权不能新增或改投；复议重验证为 `0` 时必须删除旧票。
