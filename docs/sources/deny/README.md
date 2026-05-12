# DenySource

DenySource 判断“某身份 / 地址是否被禁言”。

## 主协议语义

- `denySource = address(0)` 表示无黑名单。
- 非零 `denySource` 必须有代码。
- `isDenied(...) == true` 时，`post(...)` 整笔 revert。
- `denySource` 调用失败时，`canPost(...)` 返回 `DenySourceFailed.selector`。
- 豁免名单不是主协议概念；如果需要，由具体 DenySource 内部实现。

## 接口

```solidity
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
```

## 当前文档

- [AdminDenySource](./admin-deny-source.md)
- [GovVotedDenySource](./gov-voted-deny-source.md)

专用接口位于：

- `src/interfaces/sources/deny/IAdminDenySource.sol`
- `src/interfaces/sources/deny/IGovVotedDenySource.sol`

## 共同约束

- 不得保存 chat owner 或 delegate 当前 owner 快照。
- 权限判断必须实时读取 `GroupChat`。
- 状态必须按 `groupId` 隔离。
- 不允许 DenySource 级全局管理员绕过 chat 控制权。

## 前端规则

- 未在可信地址表中的 denySource，不调用专用展示接口。
- 可信 denySource 可选实现 `stateVersion(groupId)` 和 `StateVersionChanged`，供前端重拉专用状态。
- 消息列表前端应先从已拉取消息中分别提取唯一 `senderAddress` 与唯一 `senderId`。
- 分别调用 `isAddressDeniedBatch(...)`、`isSenderIdDeniedBatch(...)`、`isSenderIdExemptBatch(...)`。
- 前端本地合成最终隐藏状态：`!senderIdExempt && (addressDenied || senderIdDenied)`。
- 这些通用批量接口只返回隐藏判断需要的布尔状态；治理票数属于 `GovVotedDenySource` 专用展示数据，应从 `addressDenyDetailsBatch(...)`、`senderIdDenyDetailsBatch(...)` 或治理目标 / 投票人分页接口获取。
- 三类结果可以按 `groupId + denySource + stateVersion + senderAddress/senderId` 分开缓存；监听黑名单相关事件或 `StateVersionChanged` 后清理对应缓存。
