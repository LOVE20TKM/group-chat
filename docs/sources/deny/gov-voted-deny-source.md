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

去中心化群聊的 `groupId` owner 是对应 Manager。该 Manager 必须实现 `src/interfaces/sources/deny/IDenyVoteWeightSource.sol`，为本合约提供 `voteWeightOf(...)`。

## 可配置项

构造参数固定外部依赖和全局黑名单生效阈值：

- `GROUP_ADDRESS`
- `PRECISION`
- `DENY_THRESHOLD_RATIO`

当前部署默认值：

- `PRECISION = 1e18`
- `DENY_THRESHOLD_RATIO = 3e15`，即支持禁言票数至少占总治理票 `0.3%`

比例单位与 `extension-group` 一致：`1e18 = 100%`。

治理语义硬编码固定：

- 实时计票
- 支持反对票
- 支持撤票
- 支持刷新票权

构造后不按群重配这些治理规则，也不通过构造参数开启 / 关闭这些能力。

如果未来需要“不支持反对票”“不可撤票”“不可刷新票权”等不同治理语义，应新增独立 DenySource 合约类型，不在 `GovVotedDenySource` 内增加模式开关。

实时计票含义：

- 不设置提案开始 / 结束窗口。
- 每次投票、反对、撤票、刷新都立即更新聚合票权。
- 每次聚合票权变化后，同步更新“已命中黑名单”结果。
- 命中黑名单结果必须同时满足：
  - `supportWeight > opposeWeight`
  - `supportWeight / totalVoteWeight(groupId) >= DENY_THRESHOLD_RATIO / PRECISION`
- `DENY_THRESHOLD_RATIO` 只在投票、反对、撤票、刷新等写入/结算路径读取；`isDenied(...)` 仅读取已结算名单。
- 地址黑名单或 `senderId` 黑名单任一命中，`isDenied(...)` 返回 `true`。
- 票权或总票权变化后的刷新责任交给社区自行决定；合约只提供可由任何人调用的 `refreshVoteBy*`，不内置 keeper 或自动重算。

## 投票模型

- 投票主体是 `address voter = msg.sender`。
- 不引入 `voterGroupId`；治理票来自地址维度的流动性质押，票权源按 `voter` 地址计算。
- `senderId` 只作为被投票目标维度，不作为投票人身份。
- 每个投票主体对同一目标只有一个当前立场：无票、赞成拉黑、反对拉黑。
- 基础目标分两类：`senderAddress` 与 `senderId`；单维度投票使用对应接口。
- `voteBySender(...)` / `clearVoteBySender(...)` / `refreshVoteBySender(...)` 由调用方显式传入发言消息快照里的 `senderId` 与 `senderAddress`，一次操作同步影响地址与 NFT 两个目标维度。
- `senderId == 0` 或 `senderAddress == address(0)` 是无效输入，不作为单维度模式。
- 合约不通过 `ownerOf(senderId)` 或 `defaultGroupIdOf(senderAddress)` 推断另一半目标，避免目标在发言后转移或解绑导致漏投或投错。
- `voteBy*` 会用当前票权覆盖旧立场，`supportDeny=true` 表示赞成拉黑，`supportDeny=false` 表示反对拉黑。
- 反对票也是一种复议手段。
- `clearVoteBy*` 只撤回 `msg.sender` 自己的当前票。
- `refreshVoteBy*` 可由任何人调用，用于刷新某个 voter 对某个目标的当前票权。
- `refreshVoteBy*` 后当前票权为 `0` 时，必须删除该 voter 对该目标的当前票。
- 目标名单只包含当前至少有一个投票人的目标。
- 另外维护已结算地址黑名单和已结算 `senderId` 黑名单，供 `isDenied(...)` 与前端批量读使用。
- 某目标最后一个投票人撤票或被刷新删除后，该目标必须从目标名单移除。
- 地址目标读取票权时调用 `voteWeightOf(groupId, voter)`。
- `senderId` 目标读取票权时调用 `voteWeightOf(groupId, voter)`。
- 禁言阈值的分母读取 `totalVoteWeight(groupId)`。
- 四个 typed Manager 的 `totalVoteWeight(groupId)` 均返回 `ILOVE20Stake.govVotesNum(token)`；因此默认 `0.3%` 阈值始终按全 token 治理票计算。

## 最小接口

```solidity
function voteBySenderAddress(
    uint256 groupId,
    address senderAddress,
    bool supportDeny
) external;

function clearVoteBySenderAddress(
    uint256 groupId,
    address senderAddress
) external;

function refreshVoteBySenderAddress(
    uint256 groupId,
    address senderAddress,
    address voter
) external;

function voteBySenderId(
    uint256 groupId,
    uint256 senderId,
    bool supportDeny
) external;

function clearVoteBySenderId(
    uint256 groupId,
    uint256 senderId
) external;

function refreshVoteBySenderId(
    uint256 groupId,
    uint256 senderId,
    address voter
) external;

function voteBySender(
    uint256 groupId,
    uint256 senderId,
    address senderAddress,
    bool supportDeny
) external;

function clearVoteBySender(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external;

function refreshVoteBySender(
    uint256 groupId,
    uint256 senderId,
    address senderAddress,
    address voter
) external;

function voteWeightsBySenderAddressesByVoter(
    uint256 groupId,
    address[] calldata senderAddresses,
    address voter
) external view returns (uint256[] memory supportWeights, uint256[] memory opposeWeights);

function voteWeightsBySenderIdsByVoter(
    uint256 groupId,
    uint256[] calldata senderIds,
    address voter
) external view returns (uint256[] memory supportWeights, uint256[] memory opposeWeights);

function voteStatusBySenderAddress(
    uint256 groupId,
    address senderAddress
) external view returns (bool denied, uint256 supportWeight, uint256 opposeWeight);

function voteStatusBySenderAddresses(
    uint256 groupId,
    address[] calldata senderAddresses
) external view returns (
    bool[] memory denied,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
);

function voteStatusBySenderId(
    uint256 groupId,
    uint256 senderId
) external view returns (bool denied, uint256 supportWeight, uint256 opposeWeight);

function voteStatusBySenderIds(
    uint256 groupId,
    uint256[] calldata senderIds
) external view returns (
    bool[] memory denied,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
);

function votedSenderAddressesCount(
    uint256 groupId
) external view returns (uint256);

function votedSenderAddresses(
    uint256 groupId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory senderAddresses,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function votedSenderIdsCount(
    uint256 groupId
) external view returns (uint256);

function votedSenderIds(
    uint256 groupId,
    uint256 offset,
    uint256 limit
) external view returns (
    uint256[] memory senderIds,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights,
    uint256[] memory voterCounts
);

function votersBySenderAddressCount(
    uint256 groupId,
    address senderAddress
) external view returns (uint256);

function votersBySenderAddress(
    uint256 groupId,
    address senderAddress,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
);

function votersBySenderIdCount(
    uint256 groupId,
    uint256 senderId
) external view returns (uint256);

function votersBySenderId(
    uint256 groupId,
    uint256 senderId,
    uint256 offset,
    uint256 limit
) external view returns (
    address[] memory voters,
    uint256[] memory supportWeights,
    uint256[] memory opposeWeights
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

function isAddressDeniedBatch(
    uint256 groupId,
    address[] calldata senderAddresses
) external view returns (bool[] memory denied);

function isSenderIdDeniedBatch(
    uint256 groupId,
    uint256[] calldata senderIds
) external view returns (bool[] memory denied);

function stateVersion(
    uint256 groupId
) external view returns (uint256);
```

## 接口规则

- 票权源固定为 `ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId)`。
- 票权源必须是合约，并实现 `IDenyVoteWeightSource`；这是 Manager 与部署测试约束。
- 票权源不可用时，投票、反对、撤票、刷新写接口必须拒绝。
- 票权源不可用时，即 `ownerOf(groupId)` 失败或 owner 无代码，`voteWeightsBySender*ByVoter(...)` 返回与入参数组等长的 `0` 数组，`voteStatusBySender*(...)` 返回 `false, 0, 0`，投票分页接口返回空。
- `isDenied(...)`、`isAddressDeniedBatch(...)`、`isSenderIdDeniedBatch(...)` 仅读取已结算名单，不重新读取总票权。
- 通用批量黑名单读接口只返回发言 / 隐藏判断所需的布尔状态，不返回治理票数。
- 如果前端需要按指定地址或 `senderId` 解释治理黑名单原因，单个目标使用 `voteStatusBySenderAddress(...)` / `voteStatusBySenderId(...)`，批量目标使用 `voteStatusBySenderAddresses(...)` / `voteStatusBySenderIds(...)`，读取 `denied`、`supportWeight`、`opposeWeight`。
- 摘要批量接口只读取已结算名单和当前存储的聚合票数，不重新读取票权源或总票权。
- 如果前端需要目标列表或投票人明细，继续使用 `votedSenderAddresses(...)`、`votedSenderIds(...)` 或对应 voters 分页。
- `senderAddress == address(0)` 必须拒绝。
- `senderId == 0` 必须拒绝。
- 单个 voter 对某个目标当前无票时，`voteWeightsBySender*ByVoter(...)` 对应下标返回 `supportWeight=0, opposeWeight=0`。
- 单个 voter 对某个目标当前有票时，对应下标只会有一侧权重大于 `0`：支持拉黑票返回 `supportWeight > 0`，反对拉黑票返回 `opposeWeight > 0`。
- `voteBy*` 读取到的当前票权必须 `> 0`，否则拒绝。
- 重复投相同立场且票权未变化时必须拒绝。
- 已无当前票时调用 `clearVoteBy*(...)` 必须拒绝。
- `refreshVoteBy*(...)` 只处理已有当前票的 voter；无当前票必须拒绝。
- `refreshVoteBy*(...)` 读取到当前票权为 `0` 时，必须等价于删除该 voter 当前票。
- `refreshVoteBy*(...)` 读取到当前票权未变化，但总票权阈值导致黑名单结果变化时，必须更新已结算名单并递增 `stateVersion`。
- 单目标是否命中由写入/刷新路径根据 `supportWeight > opposeWeight` 与全局阈值同步到已结算名单。
- `isAddressDeniedBatch(...)`、`isSenderIdDeniedBatch(...)` 返回顺序必须与入参数组顺序一致。
- `voteWeightsBySenderAddressesByVoter(...)`、`voteWeightsBySenderIdsByVoter(...)` 返回的两组数组长度和顺序必须与入参数组一致；未出现过的目标返回 `supportWeight=0, opposeWeight=0`。
- `voteStatusBySenderAddresses(...)`、`voteStatusBySenderIds(...)` 返回的三组数组长度和顺序必须与入参数组一致；未出现过的目标返回 `denied=false, supportWeight=0, opposeWeight=0`。
- 分页接口 `limit == 0` 或 `offset` 越界时返回空数组。
- 同一分页接口返回的数组长度必须一致。
- voted sender 与投票人列表必须去重，返回顺序不作协议承诺。
- 任意外部投票写调用发生至少一项实际状态变化时，必须递增一次对应 `groupId` 的 `stateVersion`。
- `*BySender*` 联动写接口若同时改变地址目标和 NFT 目标，两条明细事件必须使用同一个 `stateVersion`，且只发出一条 `StateVersionChanged`。

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
- `uint256 constant PRECISION`
- `uint256 immutable DENY_THRESHOLD_RATIO`

每个 `groupId` 至少维护：

- `uint256 stateVersion`
- `address[] votedSenderAddresses` 与对应 `indexPlusOne`
- `uint256[] votedSenderIds` 与对应 `indexPlusOne`
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
- 不做全量重算接口，避免 `isDenied(...)` 或刷新写入依赖不可控循环。
- `0` 票权不能新增或改投；刷新为 `0` 时必须删除旧票。
