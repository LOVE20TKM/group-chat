# BanSource

BanSource 判断“某身份 / 地址是否被禁言”。

## 主协议语义

- `banSource = address(0)` 表示无黑名单。
- 非零 `banSource` 必须有代码。
- `isBanned(...) == true` 时，`post(...)` 整笔 revert。
- `banSource` 调用失败时，`canPost(...)` 返回 `BanSourceFailed.selector`。

## 主协议接口

```solidity
function isBanned(
    uint256 groupId,
    uint256 senderId,
    address senderAddress
) external view returns (bool);
```

`IPostBanSource` 只回答主协议发帖路径需要的问题。名单、投票状态都属于具体 ban 模块的展示 / 管理接口。

## 当前文档

- [AdminBanSource](./admin-ban-source.md)
- [GovVotedBanSource](./gov-voted-ban-source.md)

专用接口位于：

- `src/interfaces/sources/ban/IAdminBanSource.sol`
- `src/interfaces/sources/ban/IBanVoteWeightSource.sol`
- `src/interfaces/sources/ban/IGovVotedBanSource.sol`

## 共同约束

- 不得保存 chat owner 或 delegate 当前 owner 快照。
- 权限判断必须实时读取 `GroupChat`。
- 状态必须按 `groupId` 隔离。
- 不允许 BanSource 级全局管理员绕过 chat 控制权。

## 前端规则

- 未在可信地址表中的 banSource，只调用主协议接口 `isBanned(...)`。
- 手工黑名单状态读取 `GroupBanList.stateVersion(groupId)` 与 `GroupBanList.ChangeStateVersion`。
- 消息列表前端应先从已拉取消息中分别提取唯一 `senderAddress` 与唯一 `senderId`。
- `GroupBanList` 展示隐藏状态时，可分别调用 `addressBanDetails(...)`、`senderIdBanDetails(...)`，并本地合成 `addressBanned || senderIdBanned`；详情接口同时返回 `operatorAddresses` 与 `operatorIds`。
- `GroupBanList` 展示当前黑名单列表时，分页接口已返回同页操作者；任意目标查询也使用详情接口，不需要额外的操作者查询接口。
- `GovVotedBanSource` 展示隐藏状态时，只调用 `isAddressBannedBatch(...)`、`isSenderIdBannedBatch(...)`。
- 治理票数属于 `GovVotedBanSource` 专用展示数据，应从 `voteStatusBySenderAddresses(...)`、`voteStatusBySenderIds(...)` 或 voted sender / 投票人分页接口获取。
- `GovVotedBanSource` 展示当前用户对列表目标的投票状态时，可用 `voteWeightsBySenderAddressesByVoter(...)`、`voteWeightsBySenderIdsByVoter(...)` 按当前默认地址批量查询。
- 展示结果可以按 `groupId + banSource + stateVersion + senderAddress/senderId` 分开缓存；监听黑名单相关事件或 `ChangeStateVersion` 后清理对应缓存。
